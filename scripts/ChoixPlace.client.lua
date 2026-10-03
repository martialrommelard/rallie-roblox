-- =========================================================
--  L ECRAN "CHOISIS TA PLACE"  (LocalScript : il tourne CHEZ LE JOUEUR)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  Il s ouvre quand le joueur appuie sur le bouton du spawn. Il dessine
--  la grille de depart vue de dessus : les places libres, les places
--  prises (avec le pseudo), la sienne en vert. Un clic = un choix,
--  envoye au serveur (script DepartCourse), qui decide de tout.
--  L ecran est construit ici, en code : rien a poser a la main.
--
--   ┌───────────────────────────────┐
--   │      CHOISIS TA PLACE         │
--   │      grille de depart         │
--   │  ┌─────────────────────────┐  │
--   │  │▀▄▀▄▀▄▀▄ DEPART ▄▀▄▀▄▀▄▀│  │  <- damier
--   │  │ [ P1 ]   ┊              │  │
--   │  │          ┊   [ P2 ]     │  │  <- les places, en quinconce
--   │  │ [ P3 ]   ┊              │  │
--   │  └─────────────────────────┘  │
--   │  Prets : 1 / 2   depart 24 s  │
--   │         [ ANNULER ]           │
--   └───────────────────────────────┘
-- =========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local joueur = Players.LocalPlayer
local evt    = ReplicatedStorage:WaitForChild("DepartCourse")

local NEON   = Color3.fromRGB(0, 225, 255)
local FOND   = Color3.fromRGB(16, 19, 27)
local ROUTE  = Color3.fromRGB(48, 51, 58)
local LIBRE  = Color3.fromRGB(28, 34, 46)
local MOI    = Color3.fromRGB(46, 180, 100)
local PRISE  = Color3.fromRGB(70, 72, 82)
local BLANC  = Color3.fromRGB(240, 245, 255)
local GRIS   = Color3.fromRGB(150, 158, 175)

local LARG, HAUT = 440, 540      -- la fenetre
local ROUTE_L, ROUTE_H = 300, 330
local CASE_L, CASE_H = 118, 42
local PAS = 44                   -- ecart vertical entre deux places (62 + 5 x 44 + 42 = 324 < 330)

-- ---- PETITS OUTILS ----
local function arrondir(objet, rayon)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, rayon)
	c.Parent = objet
end

local function cadre(parent, pos, taille, couleur)
	local f = Instance.new("Frame")
	f.Position, f.Size = pos, taille
	f.BackgroundColor3 = couleur
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- un texte a taille FIXE (plus net qu un texte qui s etire)
local function texte(parent, pos, taille, police, tailleTexte, couleur, aligne)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position, t.Size = pos, taille
	t.Font, t.TextSize, t.TextColor3 = police, tailleTexte, couleur
	t.TextXAlignment = aligne or Enum.TextXAlignment.Center
	t.Text = ""
	t.Parent = parent
	return t
end

-- ---- LA FENETRE ----
local gui = Instance.new("ScreenGui")
gui.Name = "ChoixPlace"
gui.ResetOnSpawn = false     -- elle ne disparait pas quand le personnage meurt
gui.Enabled = false
gui.Parent = joueur:WaitForChild("PlayerGui")

local fenetre = cadre(gui, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(LARG, HAUT), FOND)
fenetre.AnchorPoint = Vector2.new(0.5, 0.5)
arrondir(fenetre, 18)
local bord = Instance.new("UIStroke")
bord.Color, bord.Thickness, bord.Transparency = NEON, 2, 0.2
bord.Parent = fenetre

texte(fenetre, UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, 28, NEON).Text = "CHOISIS TA PLACE"
texte(fenetre, UDim2.fromOffset(0, 50), UDim2.new(1, 0, 0, 18), Enum.Font.Gotham, 15, GRIS).Text = "grille de départ — clique sur une place libre"

-- ---- LA PISTE, VUE DE DESSUS (on roule vers le haut) ----
local piste = cadre(fenetre, UDim2.new(0.5, 0, 0, 82), UDim2.fromOffset(ROUTE_L, ROUTE_H), ROUTE)
piste.AnchorPoint = Vector2.new(0.5, 0)
arrondir(piste, 10)
-- les bords blancs
cadre(piste, UDim2.fromOffset(6, 0), UDim2.new(0, 3, 1, 0), BLANC)
cadre(piste, UDim2.new(1, -9, 0, 0), UDim2.new(0, 3, 1, 0), BLANC)
-- la ligne de depart en damier : 2 rangees de petits carres
local NB_CARRES, CARRE = 20, ROUTE_L / 20
for rangee = 0, 1 do
	for k = 0, NB_CARRES - 1 do
		local noir = (k + rangee) % 2 == 0
		cadre(piste, UDim2.fromOffset(k * CARRE, 22 + rangee * CARRE), UDim2.fromOffset(CARRE, CARRE),
			noir and Color3.fromRGB(20, 20, 24) or BLANC)
	end
end
texte(piste, UDim2.fromOffset(0, 3), UDim2.new(1, 0, 0, 16), Enum.Font.GothamBold, 13, BLANC).Text = "▲  SENS DE LA COURSE  ▲"
-- la ligne pointillee au milieu, entre les deux colonnes
for y = 62, ROUTE_H - 20, 22 do
	cadre(piste, UDim2.new(0.5, -1, 0, y), UDim2.fromOffset(2, 12), Color3.fromRGB(200, 200, 205))
end

-- ---- LE BAS : l etat, et le bouton Annuler ----
local statut = texte(fenetre, UDim2.fromOffset(24, 424), UDim2.new(1, -48, 0, 40), Enum.Font.GothamMedium, 16, BLANC)
statut.TextWrapped = true

local annuler = Instance.new("TextButton")
annuler.AnchorPoint = Vector2.new(0.5, 0)
annuler.Position = UDim2.new(0.5, 0, 0, 474)
annuler.Size = UDim2.fromOffset(170, 40)
annuler.BackgroundColor3 = FOND
annuler.Font, annuler.TextSize, annuler.TextColor3 = Enum.Font.GothamBold, 17, Color3.fromRGB(255, 110, 120)
annuler.Text = "ANNULER"
annuler.Parent = fenetre
arrondir(annuler, 10)
local bordAnnuler = Instance.new("UIStroke")
bordAnnuler.Color = Color3.fromRGB(255, 110, 120)
bordAnnuler.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bordAnnuler.Parent = annuler
annuler.MouseButton1Click:Connect(function()
	evt:FireServer("annuler")
	gui.Enabled = false
end)

-- un petit message en haut de l ecran (ex : "une course est en cours"),
-- dans son propre ScreenGui : il doit s afficher meme fenetre fermee
local guiMessage = Instance.new("ScreenGui")
guiMessage.Name = "MessageCourse"
guiMessage.ResetOnSpawn = false
guiMessage.Parent = joueur.PlayerGui
local message = texte(guiMessage, UDim2.new(0.5, -280, 0, 90), UDim2.fromOffset(560, 30),
	Enum.Font.GothamBold, 20, Color3.fromRGB(255, 210, 90))

-- ---- DESSINER LES PLACES ----
local cases = {}
local function dessiner(e)
	for _, c in ipairs(cases) do c:Destroy() end
	cases = {}
	for _, p in ipairs(e.places) do
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AnchorPoint = Vector2.new(0.5, 0)
		-- a gauche ou a droite selon le cote de la place ; de plus en plus
		-- bas selon son rang (P1 tout en haut, pres de la ligne)
		b.Position = UDim2.new(0.5, p.cote * (ROUTE_L / 4 + 2), 0, 62 + (p.rang - 1) * PAS)
		b.Size = UDim2.fromOffset(CASE_L, CASE_H)
		b.AutoButtonColor = false
		b.Parent = piste
		arrondir(b, 8)
		local numero = texte(b, UDim2.fromOffset(10, 0), UDim2.new(0, 40, 1, 0), Enum.Font.GothamBlack, 20, BLANC,
			Enum.TextXAlignment.Left)
		numero.Text = "P" .. p.rang
		local etiquette = texte(b, UDim2.fromOffset(48, 0), UDim2.new(1, -54, 1, 0), Enum.Font.GothamMedium, 13, GRIS,
			Enum.TextXAlignment.Left)
		etiquette.TextTruncate = Enum.TextTruncate.AtEnd
		local trait = Instance.new("UIStroke")
		trait.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		trait.Parent = b
		if p.pris == joueur.Name then
			b.BackgroundColor3 = MOI
			trait.Color = Color3.fromRGB(150, 255, 190)
			etiquette.Text, etiquette.TextColor3 = "TOI", BLANC
		elseif p.pris then
			b.BackgroundColor3 = PRISE
			trait.Color, trait.Transparency = PRISE, 0
			etiquette.Text = p.pris
			numero.TextColor3 = GRIS
		else
			b.BackgroundColor3 = LIBRE
			trait.Color = NEON
			etiquette.Text, etiquette.TextColor3 = "Libre", NEON
			b.AutoButtonColor = true
			b.MouseButton1Click:Connect(function()
				evt:FireServer("choisir", p.nom)
			end)
		end
		table.insert(cases, b)
	end
	if e.prets == 0 then
		statut.Text = "Choisis ta place : la course part quand tout le monde est prêt."
	else
		statut.Text = string.format("Prêts : %d / %d joueurs%s", e.prets, e.joueurs,
			e.reste and ("   •   départ dans " .. e.reste .. " s au plus tard") or "")
	end
end

-- ---- CE QUE LE SERVEUR NOUS DIT ----
evt.OnClientEvent:Connect(function(action, donnees)
	if action == "ouvrir" then
		dessiner(donnees)
		gui.Enabled = true
	elseif action == "etat" then
		dessiner(donnees)
	elseif action == "fermer" then
		gui.Enabled = false
	elseif action == "message" then
		message.Text = donnees
		task.delay(3, function()
			if message.Text == donnees then message.Text = "" end
		end)
	end
end)
