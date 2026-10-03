-- ============================================================
--  L ECRAN DE DEPART  (LocalScript : il tourne CHEZ LE JOUEUR)
--  A placer dans StarterGui > EcranDepart (le ScreenGui).
--
--  Le script des feux est sur le SERVEUR : il est le meme pour tout le
--  monde, et il ne peut pas ecrire sur un ecran en particulier. Il envoie
--  donc un message par le RemoteEvent "CompteARebours", et c est ce
--  script-ci, present chez chaque joueur, qui affiche le texte.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local evenement = ReplicatedStorage:WaitForChild("CompteARebours")
local chiffre   = script.Parent:WaitForChild("Chiffre")

local TAILLE  = UDim2.fromScale(0.35, 0.35)   -- taille a l apparition
local GROSSIE = UDim2.fromScale(0.55, 0.55)   -- taille a la fin
local DUREE   = 0.8                           -- duree de l animation

chiffre.TextTransparency = 1
chiffre.TextStrokeTransparency = 1

-- OnClientEvent : "quand le serveur m envoie un message". Les valeurs
-- envoyees par FireAllClients arrivent ici dans le meme ordre.
evenement.OnClientEvent:Connect(function(texte, couleur)
	chiffre.Text = texte
	chiffre.TextColor3 = couleur

	-- on remet tout a l etat de depart, sinon la 2e apparition partirait
	-- de la taille et de la transparence laissees par la 1re.
	chiffre.Size = TAILLE
	chiffre.TextTransparency = 0
	chiffre.TextStrokeTransparency = 0

	-- puis il grossit en s effacant : ca donne du punch sans rien dessiner.
	local info = TweenInfo.new(DUREE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(chiffre, info, {
		Size = GROSSIE,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
end)

-- ============================================================
--  LE COMPTEUR DE TOURS (le panneau en bas a gauche)
--  Meme principe : le serveur compte, et nous envoie quoi afficher.
-- ============================================================

local majTours = ReplicatedStorage:WaitForChild("MajTours")
local panneau  = script.Parent:WaitForChild("Panneau")
local titre    = panneau:WaitForChild("Titre")
local valeur   = panneau:WaitForChild("Valeur")

-- ============================================================
--  LE CHRONO (en haut au milieu de l ecran)
--  Le serveur a note l heure du feu vert dans workspace.HeureDepart.
--  GetServerTimeNow() donne la meme heure ici que sur le serveur : on
--  calcule donc nous-memes "maintenant - depart", a chaque image.
-- ============================================================
local RunService  = game:GetService("RunService")
local boiteChrono = script.Parent:WaitForChild("BoiteChrono")
local chrono      = boiteChrono:WaitForChild("Chrono")

local BLANC = Color3.fromRGB(255, 255, 255)
local tempsFinal = nil   -- nil tant que je roule ; mon temps quand j ai fini

-- 83.456 secondes  ->  "1:23.45"
local function enTexte(t)
	local minutes = math.floor(t / 60)
	local secondes = t - minutes * 60
	return string.format("%d:%05.2f", minutes, secondes)
end

-- Nouvelle course : on repart de zero.
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	if workspace:GetAttribute("CourseEnCours") then
		tempsFinal = nil
		chrono.TextColor3 = BLANC
	end
end)

-- RenderStepped : a chaque image, juste avant de la dessiner.
RunService.RenderStepped:Connect(function()
	local depart = workspace:GetAttribute("HeureDepart")
	if tempsFinal then
		chrono.Text = enTexte(tempsFinal)          -- fige
	elseif depart and workspace:GetAttribute("CourseEnCours") then
		chrono.Text = enTexte(workspace:GetServerTimeNow() - depart)
	end
end)

majTours.OnClientEvent:Connect(function(tour, total, fini, temps)
	panneau.Visible = true
	boiteChrono.Visible = true   -- seuls les pilotes le recoivent : pas les spectateurs

	-- Le serveur envoie le temps officiel quand j ai fini (ou suis elimine) :
	-- le chrono s arrete dessus.
	if fini and temps then
		tempsFinal = temps
		chrono.TextColor3 = (fini == "elimine") and Color3.fromRGB(255, 70, 70)
			or Color3.fromRGB(120, 255, 150)
	end

	-- "fini" vaut true (arrive), false (en course) ou "elimine" (sorti).
	if fini == "elimine" then
		titre.Text = "COURSE"
		valeur.Text = "ELIMINE"
		valeur.TextColor3 = Color3.fromRGB(255, 70, 70)
	elseif fini then
		titre.Text = "COURSE"
		valeur.Text = "TERMINEE"
		valeur.TextColor3 = Color3.fromRGB(120, 255, 150)
	else
		titre.Text = "TOUR"
		valeur.Text = tour .. " / " .. total
		valeur.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end)
