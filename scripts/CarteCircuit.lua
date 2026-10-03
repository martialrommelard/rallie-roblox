-- =========================================================
--  LA CARTE DU CIRCUIT, POUR LA MINIMAP
--  A placer dans ServerScriptService.
--
--  Pourquoi le serveur ? A cause du STREAMING : pour aller plus vite,
--  Roblox n envoie a chaque joueur que les objets PROCHES de lui. Au
--  lancement, son ecran ne connait que ~20 morceaux de route sur 187 :
--  une minimap dessinee avec ca serait fausse. Le serveur, lui, a TOUT
--  le circuit : il prepare la liste une fois, et la minimap (LocalScript
--  StarterPlayerScripts/Minimap) la lui demande au demarrage.
--
--  RemoteFunction = une QUESTION avec une REPONSE (un RemoteEvent, lui,
--  n est qu un message, sans reponse).
-- =========================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local circuit = workspace:WaitForChild("Circuit")
local route   = circuit:WaitForChild("Route")
local ligne   = circuit:WaitForChild("LigneDepart")

-- La liste : pour chaque morceau, juste ce qu il faut pour le dessiner
-- vu de dessus (on oublie la hauteur).
local function preparer()
	local morceaux = {}
	for _, p in ipairs(route:GetChildren()) do
		if p:IsA("BasePart") then
			local sens = p.CFrame.LookVector
			table.insert(morceaux, {
				x = p.Position.X, z = p.Position.Z,   -- le centre
				sx = sens.X, sz = sens.Z,             -- le sens du morceau
				long = p.Size.Z, larg = p.Size.X,
			})
		end
	end
	local travers = ligne.CFrame.RightVector
	return {
		morceaux = morceaux,
		ligne = {x = ligne.Position.X, z = ligne.Position.Z, sx = travers.X, sz = travers.Z, long = ligne.Size.X},
	}
end

local carte = preparer()

local question = ReplicatedStorage:FindFirstChild("CarteCircuit")
if not question then
	question = Instance.new("RemoteFunction")
	question.Name = "CarteCircuit"
	question.Parent = ReplicatedStorage
end
-- quand un ecran demande la carte, on la lui renvoie
question.OnServerInvoke = function()
	return carte
end
