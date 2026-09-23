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

majTours.OnClientEvent:Connect(function(tour, total, fini)
	panneau.Visible = true

	if fini then
		titre.Text = "COURSE"
		valeur.Text = "TERMINEE"
		valeur.TextColor3 = Color3.fromRGB(120, 255, 150)
	else
		titre.Text = "TOUR"
		valeur.Text = tour .. " / " .. total
		valeur.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end)
