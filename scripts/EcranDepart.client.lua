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

-- ============================================================
--  LE RESULTAT (en grand, au milieu de l ecran)
--  ELIMINE en rouge : il s en va quand on reapparait au spawn.
--  A l arrivee, en vert : la place dans la course et le temps
--  ("1er  —  0:47.84"), pendant DUREE_RESULTAT secondes.
--  L etiquette est creee ici si elle manque : rien a poser a la main.
-- ============================================================
local ROUGE          = Color3.fromRGB(255, 70, 70)
local VERT           = Color3.fromRGB(110, 255, 150)
local DUREE_RESULTAT = 10

local resultat = script.Parent:FindFirstChild("Resultat")
if not resultat then
	resultat = Instance.new("TextLabel")
	resultat.Name = "Resultat"
	resultat.AnchorPoint = Vector2.new(0.5, 0.5)
	resultat.Position = UDim2.fromScale(0.5, 0.3)
	resultat.Size = UDim2.fromScale(0.6, 0.13)
	resultat.BackgroundTransparency = 1
	resultat.Font = Enum.Font.GothamBlack
	resultat.TextScaled = true
	resultat.TextStrokeTransparency = 0.3
	resultat.Visible = false
	resultat.Parent = script.Parent
end

-- 1 -> "1er", 2 -> "2ème", 3 -> "3ème"...
local function enPlace(rang)
	return (rang == 1) and "1er" or (rang .. "ème")
end

-- Chaque affichage a un numero : un vieux "cacher dans 10 s" ne doit pas
-- effacer un resultat plus recent.
local numeroAffichage = 0
local function montrer(texte, couleur, duree)
	numeroAffichage += 1
	local n = numeroAffichage
	resultat.Text, resultat.TextColor3 = texte, couleur
	resultat.Visible = true
	if duree then
		task.delay(duree, function()
			if numeroAffichage == n then resultat.Visible = false end
		end)
	end
end
local function cacherResultat()
	numeroAffichage += 1
	resultat.Visible = false
end

-- On reapparait au spawn (nouveau personnage) : ELIMINE s en va.
game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
	if resultat.Visible and resultat.TextColor3 == ROUGE then
		cacherResultat()
	end
end)

-- Nouvelle course : on repart de zero.
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	if workspace:GetAttribute("CourseEnCours") then
		tempsFinal = nil
		chrono.TextColor3 = BLANC
		cacherResultat()
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

-- "fini" vaut false (en course), true (arrive) ou "elimine" (sorti).
-- "temps" (le temps officiel) et "rang" (la place a l arrivee) viennent
-- du serveur : l ecran ne fait qu afficher.
majTours.OnClientEvent:Connect(function(tour, total, fini, temps, rang)
	if fini then
		-- FINI ou ELIMINE : le chrono et les tours disparaissent
		tempsFinal = temps
		panneau.Visible = false
		boiteChrono.Visible = false
		if fini == "elimine" then
			montrer("ÉLIMINÉ", ROUGE)                    -- jusqu au retour au spawn
		else
			montrer(enPlace(rang or 1) .. "  —  " .. enTexte(temps or 0), VERT, DUREE_RESULTAT)
		end
		return
	end

	-- EN COURSE : le panneau des tours et le chrono (seuls les pilotes
	-- recoivent ce message : pas les spectateurs)
	cacherResultat()
	panneau.Visible = true
	boiteChrono.Visible = true
	titre.Text = "TOUR"
	valeur.Text = tour .. " / " .. total
	valeur.TextColor3 = BLANC
end)
