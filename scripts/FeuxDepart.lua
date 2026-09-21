-- ============================================================
--  FEUX DE DEPART
--  A placer dans ServerScriptService (c est un Script, pas un
--  LocalScript : les feux doivent etre les memes pour tout le monde).
--
--  Le portique a 4 colonnes de 3 ampoules. Le compte a rebours se lit
--  LIGNE par LIGNE, pas colonne par colonne :
--
--     0 s : la ligne 1 (en haut) devient ROUGE
--     1 s : la ligne 2 devient rouge AUSSI (la 1 reste allumee)
--     2 s : la ligne 3 devient rouge AUSSI
--     3 s : tout passe au VERT  ->  DEPART
--
--  C est pour ca que les ampoules s appellent Ampoule1, Ampoule2 et
--  Ampoule3 dans chaque colonne : le numero, c est la LIGNE.
-- ============================================================

local feux = workspace:WaitForChild("Circuit"):WaitForChild("FeuxDepart")

local ROUGE  = Color3.fromRGB(255, 40, 40)
local VERT   = Color3.fromRGB(60, 255, 110)
local ETEINT = Color3.fromRGB(58, 16, 16)

local NB_LIGNES = 3
local DUREE     = 1    -- secondes entre deux lignes
local VERT_TENU = 3    -- combien de temps le vert reste allume
local RELANCE   = 20   -- PROVISOIRE : on rejoue le depart en boucle pour
                       -- pouvoir le regarder. Le CHRONO remplacera ca.

-- Rend toutes les ampoules d une meme LIGNE, quelle que soit la colonne.
local function ligne(n)
	local t = {}
	for _, colonne in ipairs(feux:GetChildren()) do
		if colonne:IsA("Model") then
			local a = colonne:FindFirstChild("Ampoule" .. n)
			if a then table.insert(t, a) end
		end
	end
	return t
end

-- Une ampoule ETEINTE est en plastique sombre ; une ampoule ALLUMEE est
-- en Neon et sa lumiere est activee. Sans le Neon, une ampoule rouge vif
-- reste terne : c est la matiere qui fait l effet "allume".
local function peindre(ampoules, couleur, allumee)
	for _, a in ipairs(ampoules) do
		a.Color = couleur
		a.Material = allumee and Enum.Material.Neon or Enum.Material.SmoothPlastic
		local lumiere = a:FindFirstChildOfClass("PointLight")
		if lumiere then
			lumiere.Color = couleur
			lumiere.Enabled = allumee
		end
	end
end

local function toutEteindre()
	for n = 1, NB_LIGNES do
		peindre(ligne(n), ETEINT, false)
	end
end

local function compteARebours()
	toutEteindre()
	task.wait(1)

	-- On n eteint PAS la ligne precedente : elles s ajoutent.
	for n = 1, NB_LIGNES do
		peindre(ligne(n), ROUGE, true)
		task.wait(DUREE)
	end

	-- Les 3 lignes sont rouges depuis une seconde : c est le depart.
	for n = 1, NB_LIGNES do
		peindre(ligne(n), VERT, true)
	end
	print("DEPART !")          -- <<< c est ICI que le chrono demarrera

	task.wait(VERT_TENU)
	toutEteindre()
end

toutEteindre()
while true do
	compteARebours()
	task.wait(RELANCE)
end
