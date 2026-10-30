-- ============================================================
--  L ECRAN DU GARAGE
--  LocalScript a placer dans StarterPlayer > StarterPlayerScripts.
--
--  On appuie sur E a une borne du garage (sous le spawn) : un panneau
--  s ouvre a gauche, la camera se pose devant la vitrine. Trois onglets :
--    VOITURES   : acheter / choisir sa voiture ;
--    AMELIORER  : moteur, boite, freins, carrosserie (3 niveaux) ;
--    PEINTURE   : la couleur (gratuit).
--  L ecran ne decide de rien : il DEMANDE au serveur (RemoteFunction
--  "Garage"), qui verifie les pieces et repond.
--
--  La vitrine tourne et prend TA couleur... chez toi seulement : ce que
--  l ecran change dans le monde n est pas envoye aux autres joueurs.
-- ============================================================

local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local RunService             = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local joueur    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local fonction  = ReplicatedStorage:WaitForChild("Garage")
local Catalogue = require(ReplicatedStorage:WaitForChild("GarageCatalogue"))

local VITESSE_VITRINE = 0.35   -- le plateau tourne de 0.35 radian par seconde : doucement

local FOND   = Color3.fromRGB(22, 24, 30)
local CARTE  = Color3.fromRGB(38, 41, 50)
local BLEU   = Color3.fromRGB(0, 170, 230)
local VERT   = Color3.fromRGB(60, 190, 100)
local GRIS   = Color3.fromRGB(90, 92, 100)
local ROUGE  = Color3.fromRGB(230, 70, 70)
local JAUNE  = Color3.fromRGB(255, 205, 60)
local BLANC  = Color3.new(1, 1, 1)

local etat = nil          -- ce que le serveur nous a dit du garage
local onglet = "VOITURES"
local apercu = nil        -- la voiture qu on regarde (avant de l acheter)

-- =========================================================
-- LE PANNEAU
-- =========================================================
local ecran = Instance.new("ScreenGui")
ecran.Name = "EcranGarage"
ecran.ResetOnSpawn = false
ecran.Enabled = false
ecran.Parent = joueur:WaitForChild("PlayerGui")

local function coins(objet, r)
	Instance.new("UICorner", objet).CornerRadius = UDim.new(0, r or 8)
end
local function texte(parent, t, taille, position, tailleTexte, couleur, gras)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size, l.Position = taille, position
	l.Font = gras and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize = tailleTexte
	l.TextColor3 = couleur or BLANC
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = t
	l.Parent = parent
	return l
end
local function bouton(parent, t, taille, position, couleur)
	local b = Instance.new("TextButton")
	b.Size, b.Position = taille, position
	b.BackgroundColor3 = couleur
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = BLANC
	b.Text = t
	b.AutoButtonColor = true
	b.Parent = parent
	coins(b)
	return b
end

local panneau = Instance.new("Frame")
panneau.Size = UDim2.new(0, 430, 1, -40)
panneau.Position = UDim2.fromOffset(20, 20)
panneau.BackgroundColor3 = FOND
panneau.BackgroundTransparency = 0.05
panneau.Parent = ecran
coins(panneau, 14)

texte(panneau, "🔧 GARAGE", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 14), 26, BLEU, true)
local lPieces = texte(panneau, "", UDim2.new(0, 160, 0, 34), UDim2.new(1, -180, 0, 14), 20, JAUNE, true)
lPieces.TextXAlignment = Enum.TextXAlignment.Right

-- les onglets
local boutonsOnglets = {}
for i, nom in ipairs({"VOITURES", "AMÉLIORER", "PEINTURE"}) do
	local b = bouton(panneau, nom, UDim2.new(1 / 3, -14, 0, 34), UDim2.new((i - 1) / 3, i == 1 and 20 or 7, 0, 58), CARTE)
	boutonsOnglets[nom] = b
end

local contenu = Instance.new("ScrollingFrame")
contenu.Size = UDim2.new(1, -40, 1, -214)
contenu.Position = UDim2.fromOffset(20, 104)
contenu.BackgroundTransparency = 1
contenu.BorderSizePixel = 0
contenu.ScrollBarThickness = 6
contenu.AutomaticCanvasSize = Enum.AutomaticSize.Y
contenu.CanvasSize = UDim2.new()
contenu.Parent = panneau

-- le message du serveur ("Pas assez de pieces"...) et le resume
local lMessage = texte(panneau, "", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 1, -104), 15, BLANC, true)
local lEtat = texte(panneau, "", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 1, -72), 13, BLANC, true)
local lResume = texte(panneau, "", UDim2.new(1, -170, 0, 30), UDim2.new(0, 20, 1, -40), 13, Color3.fromRGB(170, 175, 185))
local fermer = bouton(panneau, "FERMER", UDim2.new(0, 110, 0, 30), UDim2.new(1, -130, 1, -40), ROUGE)

-- =========================================================
-- LA VITRINE (chez moi seulement)
-- =========================================================
local vitrine, centreVitrine, decalageVitrine = nil, nil, nil
local function trouverVitrine()
	if vitrine and vitrine.Parent then return vitrine end
	local zone = workspace:FindFirstChild("ZoneSpawn")
	local g = zone and zone:FindFirstChild("Garage")
	vitrine = g and g:FindFirstChild("VoitureVitrine")
	if vitrine then
		centreVitrine = CFrame.new(vitrine:GetAttribute("Centre"))
		decalageVitrine = centreVitrine:ToObjectSpace(vitrine:GetPivot())
	end
	return vitrine
end

local function peindreVitrine()
	if not (etat and trouverVitrine()) then return end
	local nom = apercu or etat.voiture
	-- ma voiture : avec MA peinture ; une autre : avec sa couleur a elle
	local couleur = (nom == etat.voiture) and Catalogue.couleur(nom, etat.couleur) or Catalogue.couleur(nom, 1)
	Catalogue.peindre(vitrine, couleur)
end

local angle = 0
RunService.RenderStepped:Connect(function(dt)
	if not trouverVitrine() then return end
	if (camera.CFrame.Position - centreVitrine.Position).Magnitude > 200 then return end   -- trop loin : inutile
	angle += dt * VITESSE_VITRINE
	vitrine:PivotTo(centreVitrine * CFrame.Angles(0, angle, 0) * decalageVitrine)
end)

-- =========================================================
-- CE QU ON AFFICHE
-- =========================================================
local function enX(v) return string.format("×%.2f", v) end

-- on efface tout (cartes ET mise en page) : chaque onglet remet la sienne
local function vider()
	for _, c in ipairs(contenu:GetChildren()) do c:Destroy() end
end

local demander   -- (plus bas)

local function carte(hauteur, ordre)
	local c = Instance.new("Frame")
	c.Size = UDim2.new(1, -10, 0, hauteur)
	c.BackgroundColor3 = CARTE
	c.LayoutOrder = ordre
	c.Parent = contenu
	coins(c)
	return c
end

local function prixTexte(prix)
	return etat.illimite and "GRATUIT (créateur)" or (prix .. " 🪙")
end

local AFFICHAGE = {}

function AFFICHAGE.VOITURES()
	local liste = Instance.new("UIListLayout", contenu)
	liste.Padding = UDim.new(0, 8)
	liste.SortOrder = Enum.SortOrder.LayoutOrder
	for i, v in ipairs(Catalogue.VOITURES) do
		local c = carte(104, i)
		if apercu == v.nom then
			local s = Instance.new("UIStroke", c)
			s.Color, s.Thickness = BLEU, 2
		end
		local pastille = Instance.new("Frame")
		pastille.Size, pastille.Position = UDim2.fromOffset(18, 18), UDim2.fromOffset(12, 12)
		pastille.BackgroundColor3 = v.couleur
		pastille.Parent = c
		coins(pastille, 9)
		texte(c, v.nom, UDim2.new(1, -170, 0, 22), UDim2.fromOffset(38, 9), 18, BLANC, true)
		texte(c, v.texte, UDim2.new(1, -170, 0, 34), UDim2.fromOffset(12, 34), 13, Color3.fromRGB(200, 205, 215))
		texte(c, "Moteur " .. enX(v.Puissance) .. "  Vitesse " .. enX(v.VitesseMax)
			.. "  Freins " .. enX(v.Freinage) .. "  Solidité " .. enX(v.Solidite),
			UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 78), 12, JAUNE)

		local action, libelle, couleur
		if etat.voiture == v.nom then
			libelle, couleur = "✅ EN COURSE", GRIS
		elseif etat.possede[v.nom] then
			action, libelle, couleur = "choisir", "CHOISIR", BLEU
		else
			action, libelle, couleur = "acheter", "ACHETER\n" .. prixTexte(v.prix), VERT
			if not etat.illimite and etat.pieces < v.prix then couleur = GRIS end
		end
		local b = bouton(c, libelle, UDim2.fromOffset(130, 46), UDim2.new(1, -142, 0, 10), couleur)
		b.Activated:Connect(function()
			if action then demander(action, v.nom) end
		end)
		-- cliquer sur la carte : la vitrine la montre
		local zone = Instance.new("TextButton")
		zone.BackgroundTransparency = 1
		zone.Text = ""
		zone.Size = UDim2.new(1, -150, 1, 0)
		zone.Parent = c
		zone.Activated:Connect(function()
			apercu = v.nom
			peindreVitrine()
			AFFICHAGE.rafraichir()
		end)
	end
end

local EFFETS = {Puissance = "de puissance", VitesseMax = "de vitesse max", Freinage = "de freinage", Solidite = "de solidité"}

AFFICHAGE["AMÉLIORER"] = function()
	local liste = Instance.new("UIListLayout", contenu)
	liste.Padding = UDim.new(0, 8)
	liste.SortOrder = Enum.SortOrder.LayoutOrder
	local max = #Catalogue.PRIX_NIVEAUX
	for i, a in ipairs(Catalogue.AMELIORATIONS) do
		local n = etat.niveaux[a.cle] or 0
		local c = carte(78, i)
		texte(c, a.nom, UDim2.new(1, -170, 0, 22), UDim2.fromOffset(12, 8), 18, BLANC, true)
		texte(c, string.rep("●", n) .. string.rep("○", max - n) .. "   niveau " .. n .. " / " .. max,
			UDim2.new(1, -170, 0, 18), UDim2.fromOffset(12, 32), 15, JAUNE, true)
		texte(c, "+" .. math.floor(a.effet * 100 + 0.5) .. " % " .. EFFETS[a.cle] .. " par niveau",
			UDim2.new(1, -170, 0, 16), UDim2.fromOffset(12, 54), 12, Color3.fromRGB(200, 205, 215))
		local b
		if n >= max then
			b = bouton(c, "MAX ✅", UDim2.fromOffset(130, 46), UDim2.new(1, -142, 0, 16), GRIS)
		else
			local prix = Catalogue.PRIX_NIVEAUX[n + 1]
			local couleur = (etat.illimite or etat.pieces >= prix) and VERT or GRIS
			b = bouton(c, "AMÉLIORER\n" .. prixTexte(prix), UDim2.fromOffset(130, 46), UDim2.new(1, -142, 0, 16), couleur)
			b.Activated:Connect(function() demander("ameliorer", a.cle) end)
		end
	end
end

AFFICHAGE.PEINTURE = function()
	local grille = Instance.new("UIGridLayout", contenu)
	grille.CellSize = UDim2.fromOffset(86, 86)
	grille.CellPadding = UDim2.fromOffset(8, 8)
	grille.SortOrder = Enum.SortOrder.LayoutOrder
	for i, c in ipairs(Catalogue.COULEURS) do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.BackgroundColor3 = Catalogue.couleur(etat.voiture, i)
		b.Text = ""
		b.Parent = contenu
		coins(b, 10)
		if etat.couleur == i then
			local s = Instance.new("UIStroke", b)
			s.Color, s.Thickness = BLEU, 4
		end
		local l = texte(b, c.nom, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 1, -22), 13, BLANC, true)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextStrokeTransparency = 0.2
		b.Activated:Connect(function()
			apercu = nil
			demander("couleur", i)
		end)
	end
end

function AFFICHAGE.rafraichir()
	if not etat then return end
	lPieces.Text = etat.illimite and "🪙 ∞" or ("🪙 " .. etat.pieces)
	for nom, b in pairs(boutonsOnglets) do
		b.BackgroundColor3 = (nom == onglet) and BLEU or CARTE
	end
	vider()
	AFFICHAGE[onglet]()
	-- le resume : les reglages de MA voiture pour la prochaine course
	local r = Catalogue.reglages(etat.voiture, etat.niveaux)
	lResume.Text = "Prochaine course : " .. etat.voiture .. "  —  moteur " .. enX(r.Puissance)
		.. ", vitesse " .. enX(r.VitesseMax) .. ", freins " .. enX(r.Freinage) .. ", solidité " .. enX(r.Solidite)
	-- l etat de MA voiture : les degats restent d une course a l autre
	local nbPerdues = #(etat.perdues or {})
	if (etat.etatVoiture or 100) < 100 or nbPerdues > 0 then
		lEtat.Text = string.format("🔧 État : %d %%  —  %d pièce(s) perdue(s)  →  répare-la à un POSTE (%s)",
			math.floor(etat.etatVoiture), nbPerdues, prixTexte(etat.prixReparation))
		lEtat.TextColor3 = (etat.etatVoiture <= 0) and ROUGE or JAUNE
	else
		lEtat.Text = "✅ État : 100 %  —  ta voiture est comme neuve"
		lEtat.TextColor3 = VERT
	end
end

-- =========================================================
-- PARLER AU SERVEUR
-- =========================================================
function demander(action, valeur)
	local nouveau, message, ok = fonction:InvokeServer(action, valeur)
	if nouveau then etat = nouveau end
	if message then
		lMessage.Text = message
		lMessage.TextColor3 = ok and VERT or ROUGE
	end
	if ok and (action == "acheter" or action == "choisir") then apercu = nil end
	peindreVitrine()
	AFFICHAGE.rafraichir()
end

for nom, b in pairs(boutonsOnglets) do
	b.Activated:Connect(function()
		onglet = nom
		AFFICHAGE.rafraichir()
	end)
end

-- =========================================================
-- OUVRIR / FERMER
-- =========================================================
local function ouvrir()
	if not trouverVitrine() then return end
	apercu = nil
	lMessage.Text = ""
	demander("etat")
	ecran.Enabled = true
	-- la camera : devant la vitrine, du cote ou je suis
	local perso = joueur.Character
	local ou = perso and perso:GetPivot().Position or camera.CFrame.Position
	local dir = (ou - centreVitrine.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 1 then dir = Vector3.new(0, 0, 1) end
	camera.CameraType = Enum.CameraType.Scriptable
	-- ... decalee de 7 studs vers la gauche : la voiture apparait a droite,
	-- pas cachee par le panneau
	camera.CFrame = CFrame.lookAt(centreVitrine.Position + dir.Unit * 26 + Vector3.new(0, 9, 0),
		centreVitrine.Position + Vector3.new(0, 2, 0)) * CFrame.new(-7, 0, 0)
end

local function fermerGarage()
	ecran.Enabled = false
	apercu = nil
	peindreVitrine()
	camera.CameraType = Enum.CameraType.Custom
end

fermer.Activated:Connect(fermerGarage)
joueur.CharacterAdded:Connect(function()
	if ecran.Enabled then fermerGarage() end
end)

-- PromptTriggered marche aussi sur l ecran du joueur : pas besoin de
-- passer par le serveur pour OUVRIR le panneau.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "PromptGarage" then ouvrir() end
end)

-- au debut : la vitrine prend tout de suite ma couleur
task.spawn(function()
	task.wait(3)
	etat = fonction:InvokeServer("etat")
	peindreVitrine()
end)
