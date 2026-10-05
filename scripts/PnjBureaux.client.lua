-- =========================================================
--  LES PNJ DES BUREAUX QUI TRAVAILLENT  (LocalScript : chez le joueur)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  Le serveur (script PnjBureaux) a fabrique et assis les employes.
--  Ici, on les fait bouger, a chaque image :
--    - les mains tapent sur le clavier (les epaules montent et descendent
--      un tout petit peu, la gauche et la droite chacune a son tour) ;
--    - de temps en temps, la tete se tourne vers un collegue, puis revient ;
--    - le DIRECTEUR (debout) respire, regarde tantot la salle, tantot le
--      tableau, et tapote le point avec sa baguette.
--
--  Pourquoi chez le joueur et pas sur le serveur ? Un mouvement rapide
--  envoye par le serveur arriverait par a-coups (le reseau). Chez le
--  joueur, c est fluide, et le serveur n a rien a envoyer.
--
--  Les articulations : on tourne l Attachment0 des AnimationConstraint,
--  a partir de la position assise choisie par le serveur (la "base").
-- =========================================================

local RunService = game:GetService("RunService")

local VITESSE_FRAPPE = 14     -- vitesse des mains (plus grand = tape plus vite)
local FORCE_FRAPPE   = 4      -- de combien de degres l epaule bouge
local DUREE_REGARD   = 2      -- secondes passees a regarder un collegue
local MAX_DISTANCE   = 120    -- on n anime que les PNJ a moins de 120 studs (economie)
local REGARD_TABLEAU = -55    -- le directeur tourne la tete de 55 degres a droite vers le tableau

local dossier = workspace:WaitForChild("PnjBureaux")
local camera = workspace.CurrentCamera

local pnjs = {}   -- modele -> ses articulations et leur position de base

local function articulation(perso, nomPiece, nomJoint)
	local piece = perso:FindFirstChild(nomPiece)
	local joint = piece and piece:FindFirstChild(nomJoint)
	if joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
		return {a = joint.Attachment0, base = joint.Attachment0.CFrame}
	end
end

local function ajouter(perso)
	if pnjs[perso] or not perso:IsA("Model") then return end
	if perso:GetAttribute("Debout") then
		if not perso:GetAttribute("Pret") then return end   -- le serveur vise encore le point
		-- le directeur : pas de clavier, mais le cou, la taille et le bras qui tient la baguette
		local cou    = articulation(perso, "Head", "Neck")
		local taille = articulation(perso, "UpperTorso", "Waist")
		local bras   = articulation(perso, "RightUpperArm", "RightShoulder")
		if not (cou and taille and bras) then return end
		pnjs[perso] = {debout = true, cou = cou, taille = taille, bras = bras,
			regard = 0, cible = 0, prochainRegard = os.clock() + 3}
		return
	end
	local droite = articulation(perso, "RightUpperArm", "RightShoulder")
	local gauche = articulation(perso, "LeftUpperArm", "LeftShoulder")
	local cou    = articulation(perso, "Head", "Neck")
	if not (droite and gauche and cou) then return end   -- pas encore tout recu (streaming)
	pnjs[perso] = {
		droite = droite, gauche = gauche, cou = cou,
		phase = perso:GetAttribute("Phase") or 0,
		regard = 0,                      -- l angle de la tete en ce moment
		prochainRegard = os.clock() + math.random() * 8,
		cible = 0,
	}
end

-- les PNJ arrivent petit a petit (streaming) : on regarde regulierement
task.spawn(function()
	while true do
		for _, perso in ipairs(dossier:GetChildren()) do ajouter(perso) end
		for perso in pairs(pnjs) do
			if not perso.Parent then pnjs[perso] = nil end
		end
		task.wait(1)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local oeil = camera.CFrame.Position
	for perso, p in pairs(pnjs) do
		local racine = perso.PrimaryPart or perso:FindFirstChild("HumanoidRootPart")
		if racine and (racine.Position - oeil).Magnitude < MAX_DISTANCE and p.debout then
			-- LE DIRECTEUR
			-- il respire : le haut du corps se penche a peine, lentement
			p.taille.a.CFrame = p.taille.base * CFrame.Angles(math.rad(math.sin(t * 1.6) * 1.5), 0, 0)
			-- il regarde la salle (4 a 7 s), puis le tableau derriere sa droite (2,5 s)
			if t > p.prochainRegard then
				if p.cible == 0 then
					p.cible, p.prochainRegard = REGARD_TABLEAU, t + 2.5
				else
					p.cible, p.prochainRegard = 0, t + 4 + math.random() * 3
				end
			end
			p.regard += (p.cible - p.regard) * math.min(1, dt * 4)
			p.cou.a.CFrame = p.cou.base * CFrame.Angles(0, math.rad(p.regard), 0)
			-- quand il regarde le tableau, il tapote le point avec la baguette
			local tape = (p.cible ~= 0) and math.max(0, math.sin(t * 9)) * 2 or 0
			p.bras.a.CFrame = p.bras.base * CFrame.Angles(math.rad(tape), 0, 0)
		elseif racine and (racine.Position - oeil).Magnitude < MAX_DISTANCE then
			-- LES MAINS : deux sinus decales, la gauche tape quand la droite remonte
			local x = t * VITESSE_FRAPPE + p.phase
			local d = math.max(0, math.sin(x)) * FORCE_FRAPPE
			local g = math.max(0, math.sin(x + math.pi)) * FORCE_FRAPPE
			p.droite.a.CFrame = p.droite.base * CFrame.Angles(math.rad(d), 0, 0)
			p.gauche.a.CFrame = p.gauche.base * CFrame.Angles(math.rad(g), 0, 0)

			-- LA TETE : de temps en temps, un coup d oeil a droite ou a gauche
			if t > p.prochainRegard then
				if p.cible == 0 then
					p.cible = (math.random() < 0.5) and -35 or 35
					p.prochainRegard = t + DUREE_REGARD
				else
					p.cible = 0
					p.prochainRegard = t + 4 + math.random() * 8
				end
			end
			p.regard += (p.cible - p.regard) * math.min(1, dt * 5)    -- on tourne doucement
			p.cou.a.CFrame = p.cou.base * CFrame.Angles(math.rad(-8), math.rad(p.regard), 0)  -- -8 : il regarde un peu vers l ecran
		end
	end
end)
