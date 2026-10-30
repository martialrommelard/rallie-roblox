-- ============================================================
--  LES DEGATS DES VOITURES
--  A placer dans ServerScriptService.
--
--  Chaque voiture de course a un ETAT, de 100 (neuve) a 0 (detruite),
--  pose en attribut "Etat" sur la voiture (l ecran Course.client affiche
--  la barre).
--
--  COMMENT SAIT-ON QU IL Y A EU UN CHOC ? On compare la vitesse de la
--  voiture d une image a l autre. En freinant fort, elle change de 1 ou 2
--  studs/s par image ; contre un mur, de 30, 50, 100... Au-dessus de
--  SEUIL, c est un choc, et plus il est violent, plus ca abime.
--  On ne regarde que la vitesse HORIZONTALE : retomber du tremplin (choc
--  vertical) ne doit pas abimer la voiture, ce saut est obligatoire.
--
--  Moins de 50 % : elle fume. Moins de 25 % : elle prend feu.
--  0 % : le pilote est elimine, comme une sortie de route.
--  "Solidite" (garage : voiture Belier, amelioration Carrosserie) divise
--  les degats.
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SEUIL   = 25     -- studs/s d un coup : en dessous, ce n est pas un choc
local FORCE   = 0.8    -- % perdus par stud/s au-dessus du seuil
local PROTEGE = 1.5    -- secondes apres s etre assis : on ne compte rien
                       -- (le pilote est pose dans la voiture, ca secoue)
local MIN_MSG = 3      -- on ne previent pas pour une egratignure

local ORANGE = Color3.fromRGB(255, 150, 60)

local dossier = workspace:WaitForChild("Voitures")
local info = ReplicatedStorage:WaitForChild("InfoCourse")

local avant = {}       -- [voiture] = sa vitesse horizontale a l image d avant
local depuis = {}      -- [voiture] = l heure ou le pilote s est assis

-- La fumee et le feu : poses sur le siege, allumes selon l etat.
local function effets(voiture, siege, etat)
	local fumee = siege:FindFirstChild("FumeeDegats")
	if not fumee then
		fumee = Instance.new("Smoke")
		fumee.Name = "FumeeDegats"
		fumee.Color = Color3.fromRGB(60, 60, 60)
		fumee.Size = 4
		fumee.RiseVelocity = 6
		fumee.Enabled = false
		fumee.Parent = siege
		local feu = Instance.new("Fire")
		feu.Name = "FeuDegats"
		feu.Size = 6
		feu.Enabled = false
		feu.Parent = siege
	end
	fumee.Enabled = etat < 50
	siege.FeuDegats.Enabled = etat < 25
end

-- Detruite : le pilote est elimine (CompteurTours le voit : Health = 0),
-- sa voiture disparait. Comme une sortie de route dans Voitures.
local function detruire(voiture, siege)
	local hum = siege.Occupant
	local joueur = hum and Players:GetPlayerFromCharacter(hum.Parent)
	if joueur then
		info:FireClient(joueur, "💥 VOITURE DÉTRUITE", Color3.fromRGB(255, 80, 80), 3)
		print(joueur.Name .. " : voiture detruite")
	end
	if hum then hum.Health = 0 end
	voiture:Destroy()
end

RunService.Heartbeat:Connect(function()
	local enCourse = workspace:GetAttribute("CourseEnCours") == true
	for _, voiture in ipairs(dossier:GetChildren()) do
		local siege = voiture:FindFirstChildWhichIsA("VehicleSeat", true)
		local etat = voiture:GetAttribute("Etat")
		if siege and siege.Occupant and enCourse and etat then
			depuis[voiture] = depuis[voiture] or os.clock()
			local v = siege.AssemblyLinearVelocity
			local plat = Vector3.new(v.X, 0, v.Z)

			if avant[voiture] and os.clock() - depuis[voiture] > PROTEGE then
				local choc = (plat - avant[voiture]).Magnitude
				if choc > SEUIL then
					local perte = (choc - SEUIL) * FORCE / (voiture:GetAttribute("Solidite") or 1)
					etat = math.max(0, etat - perte)
					voiture:SetAttribute("Etat", etat)
					local joueur = Players:GetPlayerFromCharacter(siege.Occupant.Parent)
					if joueur and perte >= MIN_MSG and etat > 0 then
						info:FireClient(joueur, "💥 Choc !  −" .. math.floor(perte) .. " %", ORANGE, 1.5)
					end
					effets(voiture, siege, etat)
					if etat <= 0 then
						detruire(voiture, siege)
						continue          -- elle n existe plus : voiture suivante
					end
				end
			end
			avant[voiture] = plat
		else
			avant[voiture], depuis[voiture] = nil, nil
		end
	end
end)

-- une voiture detruite ou remplacee : on oublie ce qu on savait d elle
dossier.ChildRemoved:Connect(function(voiture)
	avant[voiture], depuis[voiture] = nil, nil
end)
