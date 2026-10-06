-- =========================================================
--  LE BANC DE DEVELOPPE COUCHE  (a lancer UNE fois, dans Studio, en Edit,
--  APRES SalleSport.lua). Remplace l ancien banc (un siege, une barre qui
--  montait toute seule) par un vrai banc : banc rembourre, rack avec ses
--  crochets, barre chromee et ses disques, tapis de sol, panneau des records.
--
--  On s allonge (touche E). La barre descend sur la poitrine ; une JAUGE
--  apparait, un curseur y monte et descend : il faut cliquer quand il est
--  dans la ZONE VERTE pour pousser la barre. A chaque barre soulevee, le
--  curseur va plus vite et la zone retrecit. C est le LocalScript Exercices
--  qui fait le jeu ; le serveur (SalleSportServeur) bouge la barre et compte.
--
--  Les hauteurs sont DEDUITES de mon avatar (allonge sur le dos) :
--    - le banc est assez bas pour que les pieds touchent le sol ;
--    - la barre "en haut" = bras presque tendus ; "en bas" = sur la poitrine.
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local salle = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")
local sol = salle:WaitForChild("TapisSport")

-- ---- OU : la ou etait l ancienne barre (repere du sol de la salle de sport) ----
local POSITION = Vector3.new(5.7, 0, -7.9)

-- ---- LE PILOTE ALLONGE (mesure sur mon avatar, en studs) ----
local DOS_EPAULE = 0.54      -- du dos (sur le banc) a l articulation de l epaule
local TORSE      = 1.07      -- epaisseur du torse : la poitrine est a DOS + TORSE
local BRAS       = 1.67      -- epaule -> poignee, bras tendu
local MAINS_X    = 1.46      -- les mains, de chaque cote du milieu

local H_BANC   = 1.15                                   -- le dessus du coussin (les pieds touchent le sol)
local H_HAUT   = H_BANC + DOS_EPAULE + BRAS * 0.97      -- la barre en haut : bras presque tendus
local H_BAS    = H_BANC + TORSE + 0.2                   -- la barre en bas : sur la poitrine
local Z_EPAULES = -0.25                                 -- les epaules un peu vers la tete : la barre tombe sur le bas de la poitrine
local ECART_RACK = MAINS_X + 0.45                       -- les montants, juste a cote des mains

local GRAPHITE = Color3.fromRGB(45, 47, 52)
local CHROME   = Color3.fromRGB(190, 195, 200)
local NOIR     = Color3.fromRGB(22, 22, 25)
local ROUGE    = Color3.fromRGB(200, 30, 35)
local NEON     = Color3.fromRGB(0, 225, 255)

local enregistrement = ChangeHistoryService:TryBeginRecording("Banc de developpe couche")

-- on enleve l ancien banc (par NOM)
for _, p in ipairs(salle:GetChildren()) do
	if p.Name == "BancMuscu" or p.Name == "Barre" or p.Name == "DisqueBarre" or p.Name == "PiedBanc"
		or p.Name == "MontantBanc" or p.Name == "CoussinBanc" or p.Name == "EcranBanc" or p.Name == "BancDeMusculation" then
		p:Destroy()
	end
end

-- le repere du banc : au SOL, sous la barre ; X = le long de la barre, -Z = vers la tete
local Q = sol.CFrame * CFrame.new(POSITION + Vector3.new(0, sol.Size.Y / 2, 0))

local modele = Instance.new("Model")
modele.Name = "BancDeMusculation"
modele.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
modele:SetAttribute("Course", H_HAUT - H_BAS)        -- de combien la barre descend
modele.Parent = salle

local function piece(nom, taille, cf, couleur, matiere, forme, parent)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.Metal
	if forme then p.Shape = forme end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or modele
	return p
end

-- le tapis de sol
piece("SolBanc", Vector3.new(ECART_RACK * 2 + 1.2, 0.06, 5.4), Q * CFrame.new(0, 0.03, 0.6), NOIR, Enum.Material.Rubber)

-- le banc : coussin, cadre, pieds
local zTete, zPieds = -1.45, 2.0
local coussin = piece("CoussinBanc", Vector3.new(1.25, 0.28, zPieds - zTete), Q * CFrame.new(0, H_BANC - 0.14, (zTete + zPieds) / 2), NOIR, Enum.Material.Leather)
for _, s in ipairs({-1, 1}) do
	piece("LiserBanc", Vector3.new(0.04, 0.05, zPieds - zTete), Q * CFrame.new(s * 0.63, H_BANC - 0.06, (zTete + zPieds) / 2), ROUGE, Enum.Material.SmoothPlastic)
end
piece("CadreBanc", Vector3.new(0.4, 0.2, zPieds - zTete - 0.3), Q * CFrame.new(0, H_BANC - 0.38, (zTete + zPieds) / 2), GRAPHITE)
for _, z in ipairs({zTete + 0.4, zPieds - 0.4}) do
	piece("PiedBanc", Vector3.new(0.3, H_BANC - 0.55, 0.3), Q * CFrame.new(0, (H_BANC - 0.45) / 2 + 0.05, z), GRAPHITE)
	piece("BaseBanc", Vector3.new(1.3, 0.12, 0.4), Q * CFrame.new(0, 0.12, z), GRAPHITE)
end
-- ou s allonger : les epaules (pour Exercices)
local place = Instance.new("Attachment")
place.Name = "Epaules"
place.Parent = coussin
place.WorldPosition = (Q * CFrame.new(0, H_BANC, Z_EPAULES)).Position

-- le rack : 2 montants (un peu vers la tete, pour laisser passer la barre), crochets, traverse
local zRack = -0.35
for _, s in ipairs({-1, 1}) do
	local x = s * ECART_RACK
	piece("MontantBanc", Vector3.new(0.3, H_HAUT + 0.7, 0.3), Q * CFrame.new(x, (H_HAUT + 0.7) / 2, zRack), GRAPHITE)
	piece("BaseRack", Vector3.new(0.4, 0.15, 1.6), Q * CFrame.new(x, 0.08, zRack + 0.2), GRAPHITE)
	piece("CrochetBanc", Vector3.new(0.22, 0.12, 0.25), Q * CFrame.new(x, H_HAUT - 0.13, zRack + 0.15), ROUGE, Enum.Material.SmoothPlastic)
end
piece("TraverseRack", Vector3.new(ECART_RACK * 2 + 0.3, 0.3, 0.3), Q * CFrame.new(0, H_HAUT + 0.7, zRack), GRAPHITE)

-- la barre et ses disques : les disques sont SOUDES a la barre (le serveur ne bouge que la barre)
local barre = piece("Barre", Vector3.new(5.6, 0.14, 0.14), Q * CFrame.new(0, H_HAUT, 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
for _, s in ipairs({-1, 1}) do
	for _, d in ipairs({{"BagueBarre", 2.05, 0.12, 0.3, CHROME}, {"DisqueBarre", 2.25, 0.22, 1.5, ROUGE}, {"DisqueBarre", 2.48, 0.18, 1.1, NOIR}}) do
		local p = piece(d[1], Vector3.new(d[3], d[4], d[4]), barre.CFrame * CFrame.new(s * d[2], 0, 0), d[5], Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, barre)
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		local soudure = Instance.new("WeldConstraint")
		soudure.Part0, soudure.Part1 = barre, p
		soudure.Parent = p
	end
	-- les poignees : la ou vont les mains
	local g = piece("PoigneeBanc", Vector3.new(0.5, 0.17, 0.17), barre.CFrame * CFrame.new(s * MAINS_X, 0, 0), NOIR, Enum.Material.Rubber, Enum.PartType.Cylinder, barre)
	g.Anchored, g.CanCollide, g.Massless = false, false, true
	local soudure = Instance.new("WeldConstraint")
	soudure.Part0, soudure.Part1 = barre, g
	soudure.Parent = g
end

-- le bouton pour s allonger
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "S'allonger"
prompt.ObjectText = "Developpe couche"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 8
prompt.RequiresLineOfSight = false
prompt.Parent = coussin

-- le panneau des records, au-dessus du rack (le texte des 2 cotes)
local panneau = piece("PanneauBanc", Vector3.new(ECART_RACK * 2, 1.2, 0.15), Q * CFrame.new(0, H_HAUT + 1.5, zRack), GRAPHITE, Enum.Material.SmoothPlastic)
local g = Instance.new("SurfaceGui")
g.Face = Enum.NormalId.Front
g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
g.PixelsPerStud = 50
g.LightInfluence = 0
g.Parent = panneau
local fond = Instance.new("Frame")
fond.Size = UDim2.fromScale(1, 1)
fond.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
fond.BorderSizePixel = 0
fond.Parent = g
local t = Instance.new("TextLabel")
t.Name = "Texte"
t.Size = UDim2.new(1, -12, 1, -8)
t.Position = UDim2.fromOffset(6, 4)
t.BackgroundTransparency = 1
t.Font = Enum.Font.GothamBold
t.TextScaled = true
t.TextColor3 = NEON
t.Text = "DEVELOPPE COUCHE\nRECORD : —"
t.ZIndex = 2
t.Parent = g
g:Clone().Parent = panneau
panneau:FindFirstChildOfClass("SurfaceGui").Face = Enum.NormalId.Back

modele.PrimaryPart = barre
if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
print(string.format("Banc : coussin a %.2f, barre de %.2f (en bas) a %.2f (en haut)", H_BANC, H_BAS, H_HAUT))
