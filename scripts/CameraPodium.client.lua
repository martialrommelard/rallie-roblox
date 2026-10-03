-- =========================================================
--  LA CAMERA DE L ECRAN DU PODIUM  (LocalScript : chez le joueur)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  Le script Podium (serveur) remplit l ecran du spawn avec une copie
--  du podium. Mais une Camera creee sur le serveur n arrive pas chez
--  les joueurs : sans camera, une fenetre 3D (ViewportFrame) reste
--  NOIRE. Le serveur note donc seulement OU mettre la camera (les
--  attributs "Camera" et "Champ" de la Vue), et c est ici qu on la cree.
-- =========================================================

local function laVue()
	local zone = workspace:FindFirstChild("ZoneSpawn")
	local ecran = zone and zone:FindFirstChild("EcranPodium")
	local gui = ecran and ecran:FindFirstChild("Ecran")
	return gui and gui:FindFirstChild("Vue")
end

-- Une fois par seconde, ca suffit : la camera ne bouge que quand le
-- serveur refait l ecran (et l ecran peut arriver en retard, a cause
-- du streaming, ou etre refait par le generateur).
while true do
	local vue = laVue()
	local ou = vue and vue:GetAttribute("Camera")
	if ou then
		local camera = vue.CurrentCamera
		if not camera or camera.Parent ~= vue then
			camera = Instance.new("Camera")
			camera.Name = "CameraLocale"
			camera.Parent = vue
			vue.CurrentCamera = camera
		end
		camera.CFrame = ou
		camera.FieldOfView = vue:GetAttribute("Champ") or 50
	end
	task.wait(1)
end
