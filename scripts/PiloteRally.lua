-- ============================================================
--  LE PILOTE DE NOTRE VOITURE DE RALLY
--  ModuleScript a placer dans ReplicatedStorage, nom "PiloteRally".
--
--  C est ICI que la voiture est conduite. Deux scripts s en servent :
--    - Conduite.client (chez le joueur) : quand TU es au volant. C est
--      ton ordinateur qui fait rouler ta voiture (Roblox lui en donne le
--      controle quand tu t assois) : elle repond tout de suite, sans
--      attendre le serveur ;
--    - Conduite (dans la voiture, sur le serveur) : quand personne n est
--      dedans (la voiture s arrete) ou pour les essais.
--
--  COMME LES VOITURES DES JEUX ROBLOX : une conduite "arcade". La
--  physique fait rouler les roues (moteurs, ressorts), et TROIS AIDES
--  la rendent facile a piloter :
--    1. L ANTIPATINAGE : les roues ne tournent jamais beaucoup plus vite
--       que la voiture n avance : elles ne patinent pas au demarrage.
--    2. L ADHERENCE : quand la voiture est au sol, on lui enleve presque
--       toute sa vitesse DE COTE (la glissade) : plus de tete-a-queue.
--       En l air (tremplin), on ne touche a rien.
--    3. L AIDE AU VIRAGE : on dit a la voiture a quelle vitesse tourner
--       sur elle-meme (vitesse de rotation), selon le volant. Volant
--       lache : elle se remet droite.
-- ============================================================

local Pilote = {}

-- ---- LES REGLAGES ----
local VITESSE_MAX = 120    -- studs/s en marche avant (x VitesseMax du garage)
local VITESSE_AR  = 35     -- studs/s en marche arriere
local COUPLE      = 6500   -- la force de chaque roue pour accelerer (x Puissance)
local FREIN       = 6000   -- la force de chaque roue pour freiner (x Freinage)
local ROUE_LIBRE  = 150    -- on ne touche a rien : elle ralentit doucement
local AVANCE_ROUE = 25     -- antipatinage : la roue va au plus 25 studs/s plus vite que la voiture
local BRAQUAGE    = 35     -- l angle des roues avant a l arret (degres)...
local BRAQUAGE_VITE = 15   -- ...et a pleine vitesse
local ADHERENCE   = 10     -- combien on enleve de glissade par seconde (plus = plus colle)
local VIRAGE      = 2.4    -- vitesse de rotation voulue a fond de volant (radians/s), a vitesse moyenne...
local VIRAGE_VITE = 1.3    -- ...et a pleine vitesse (sinon c est trop nerveux)
local AIDE_VIRAGE = 6      -- a quelle vitesse la voiture rejoint cette rotation
local SOL         = 3.5    -- au sol si le dessous du chassis est a moins de 3.5 studs de quelque chose
local SENS        = -1     -- le sens de rotation des roues (mesure : -1 = elles poussent vers l avant)
local SENS_VOLANT = -1     -- le sens de la direction (mesure : -1 = SteerFloat 1 tourne a droite)

-- ce qu on retient de chaque voiture (ses roues, son chassis)
local infos = setmetatable({}, {__mode = "k"})

local function infosDe(voiture)
	if infos[voiture] then return infos[voiture] end
	local x = {
		siege = voiture:FindFirstChild("DriveSeat"),
		chassis = voiture:FindFirstChild("Chassis"),
		roues = {},
		rayon = RaycastParams.new(),
	}
	x.rayon.FilterType = Enum.RaycastFilterType.Exclude
	x.rayon.FilterDescendantsInstances = {voiture}
	-- les BLOCS qui bougent chacun de leur cote (chassis, fusees,
	-- porte-roues, roues : relies par des ressorts et des charnieres, pas
	-- soudes). Les aides doivent les pousser TOUS pareil, sinon ils tirent
	-- les uns contre les autres et la voiture louvoie (mesure).
	x.blocs = {}
	for _, p in ipairs(voiture:GetDescendants()) do
		if p:IsA("BasePart") and p.AssemblyRootPart == p then table.insert(x.blocs, p) end
	end
	for _, nom in ipairs({"AvG", "AvD", "ArG", "ArD"}) do
		local r = voiture:FindFirstChild("Roue" .. nom)
		if r then
			-- a l avant, la direction = l attache de la roue sur sa fusee :
			-- on la fait pivoter, l axe de la roue suit
			local fusee = voiture:FindFirstChild("Fusee" .. nom)
			local att = nom:sub(1, 2) == "Av" and fusee and fusee:FindFirstChild("AttMoteur")
			table.insert(x.roues, {
				roue = r,
				moteur = r:FindFirstChild("Moteur"),
				direction = att or nil,            -- nil a l arriere
				droit = att and att.CFrame,        -- l attache, roues droites
				rayon = r.Size.Y / 2,
			})
		end
	end
	infos[voiture] = x
	return x
end

-- La vitesse VERS L AVANT (negative en marche arriere)
function Pilote.vitesse(voiture)
	local x = infosDe(voiture)
	return x.siege.CFrame.LookVector:Dot(x.siege.AssemblyLinearVelocity)
end

-- A appeler a CHAQUE IMAGE. gaz : -1..1, volant : -1 (gauche)..1 (droite).
-- aides : vrai pour l adherence et l aide au virage (chez le pilote).
function Pilote.piloter(voiture, gaz, volant, dt, aides)
	local x = infosDe(voiture)
	if not (x.siege and x.chassis) then return end
	local v = Pilote.vitesse(voiture)
	local vmax = VITESSE_MAX * (voiture:GetAttribute("VitesseMax") or 1)
	local couple = COUPLE * (voiture:GetAttribute("Puissance") or 1)
	local frein = FREIN * (voiture:GetAttribute("Freinage") or 1)

	-- ---- LES ROUES ----
	local cible, force
	if gaz > 0 and v > -3 then
		-- on accelere, avec l ANTIPATINAGE
		cible, force = math.min(vmax, math.max(v, 0) + AVANCE_ROUE), couple * gaz
	elseif gaz < 0 and v > 3 then
		cible, force = 0, frein                           -- on freine (on roulait en avant)
	elseif gaz < 0 then
		cible, force = math.max(-VITESSE_AR, math.min(v, 0) - AVANCE_ROUE), couple   -- on recule
	elseif gaz > 0 then
		cible, force = 0, frein                           -- on freine (on reculait)
	else
		cible, force = 0, ROUE_LIBRE                      -- roue libre
	end
	local f = math.clamp(math.abs(v) / vmax, 0, 1)
	local angle = volant * (BRAQUAGE + (BRAQUAGE_VITE - BRAQUAGE) * f)
	for _, r in ipairs(x.roues) do
		if r.moteur and r.moteur.Parent then              -- (une roue arrachee n a plus de moteur)
			r.moteur.AngularVelocity = SENS * cible / r.rayon
			r.moteur.MotorMaxTorque = force
		end
		if r.direction and r.direction.Parent then
			r.direction.CFrame = r.droit * CFrame.Angles(0, math.rad(SENS_VOLANT * angle), 0)
		end
	end

	-- ---- LES AIDES (seulement au sol) ----
	if not aides then return end
	local ch = x.chassis
	local dessous = ch.CFrame * Vector3.new(0, -ch.Size.Y / 2, 0)
	if not workspace:Raycast(dessous, -ch.CFrame.UpVector * SOL, x.rayon) then return end   -- en l air

	-- 2. L ADHERENCE : on enleve une partie de la vitesse de cote
	local cote = ch.CFrame.RightVector
	local glisse = cote:Dot(ch.AssemblyLinearVelocity)
	local dVitesse = -cote * glisse * math.min(1, ADHERENCE * dt)

	-- 3. L AIDE AU VIRAGE : la rotation voulue (vers la droite = negative
	-- autour de l axe vertical), plus douce a l arret (on ne tourne pas
	-- sur place) et a pleine vitesse
	local aPeine = math.clamp(math.abs(v) / 15, 0, 1)            -- 0 a l arret, 1 des 15 studs/s
	local voulue = -volant * (VIRAGE + (VIRAGE_VITE - VIRAGE) * f) * aPeine * ((v >= 0) and 1 or -1)
	local haut = ch.CFrame.UpVector
	local actuelle = haut:Dot(ch.AssemblyAngularVelocity)
	local dRotation = haut * (voulue - actuelle) * math.min(1, AIDE_VIRAGE * dt)

	-- on applique ces deux changements a TOUS les blocs, comme si la
	-- voiture etait d un seul morceau : chaque bloc tourne autour du
	-- centre du chassis (sa vitesse change de dRotation x son bras de levier)
	local centre = ch.AssemblyCenterOfMass
	for _, b in ipairs(x.blocs) do
		if b.Parent and b.AssemblyRootPart == b then
			b.AssemblyLinearVelocity += dVitesse + dRotation:Cross(b.AssemblyCenterOfMass - centre)
			b.AssemblyAngularVelocity += dRotation
		end
	end
end

return Pilote
