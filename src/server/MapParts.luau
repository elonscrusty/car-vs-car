--!strict
-- The part builders live in shared/MapParts (the client builds the practice yard with them too);
-- the server files keep requiring them from here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(ReplicatedStorage.Shared.MapParts)
