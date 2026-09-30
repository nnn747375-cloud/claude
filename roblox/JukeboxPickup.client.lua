-- LocalScript (StarterPlayerScripts)
-- G: Jukebox aufheben | Linksklick: werfen | Treffer: Break- + Jukebox-Sound
-- Reihenfolge und Delays stammen aus den Detector-Timestamps (Sekunden relativ zum ersten Event).

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PICKUP_RANGE = 8
local THROW_SPEED = 90

local ANIM = {
	GrabA = "rbxassetid://16392545357",      -- 0.82s, Action, nicht geloopt   (18:55:10.427)
	GrabB = "rbxassetid://87482673772484",   -- 0.77s, Action, nicht geloopt   (18:55:10.446)
	Hold  = "rbxassetid://129755591753926",  -- geloopt, Halte-Pose            (18:55:10.879)
	Throw = "rbxassetid://125371756838669",  -- 0.88s, Action, nicht geloopt   (18:57:29.623)
}

local SOUND = {
	Grab         = { id = "rbxassetid://9113562430", volume = 10,   speed = 1    }, -- Parent: Torso
	Throw        = { id = "rbxassetid://8186570431", volume = 10,   speed = 0.75 }, -- Parent: HumanoidRootPart
	JukeboxBreak = { id = "rbxassetid://3177740718", volume = 6.02, speed = 0.93 }, -- Parent: Jukebox
	Jukebox      = { id = "rbxassetid://3521543186", volume = 5.91, speed = 1.80 }, -- Parent: Jukebox
}

-- Delays in Sekunden (aus den Detected-Zeiten berechnet)
local PICKUP = {
	GrabA = 0,                 -- 10.427
	Grab  = 0.002,             -- 10.429 (Sound)
	GrabB = 0.019,             -- 10.446
	Hold  = 0.452,             -- 10.879
}
local THROW = {
	Anim  = 0,                 -- 29.623
	Sound = 0.253,             -- 29.876
}
local HIT = {
	JukeboxBreak = 0,          -- 52.755
	Jukebox      = 0.001,      -- 52.756
}

local state = { held = nil, weld = nil, tracks = {}, busy = false }

local function playSound(def, parent)
	local s = Instance.new("Sound")
	s.SoundId, s.Volume, s.PlaybackSpeed = def.id, def.volume, def.speed
	s.Parent = parent
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	return s
end

local function loadTrack(animator, id, looped)
	local a = Instance.new("Animation")
	a.AnimationId = id
	local tr = animator:LoadAnimation(a)
	tr.Priority = Enum.AnimationPriority.Action
	tr.Looped = looped
	return tr
end

local function character()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then return end
	return c, hum, hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
end

local function nearestJukebox(root)
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Destructibles")
	local jb = folder and folder:FindFirstChild("Jukebox")
	if not jb then return end
	local part = jb:IsA("Model") and (jb.PrimaryPart or jb:FindFirstChildWhichIsA("BasePart")) or jb
	if part and (part.Position - root.Position).Magnitude <= PICKUP_RANGE then return jb, part end
end

-- Treffer: beide Sounds auf der Jukebox, in der gemessenen Reihenfolge
local function onHit(jukeboxPart)
	task.delay(HIT.JukeboxBreak, playSound, SOUND.JukeboxBreak, jukeboxPart)
	task.delay(HIT.Jukebox, playSound, SOUND.Jukebox, jukeboxPart)
end

local function pickUp()
	local c, hum, animator = character()
	if not c or state.held or state.busy then return end
	local root = c:FindFirstChild("HumanoidRootPart")
	local jb, part = nearestJukebox(root)
	if not jb then return end
	state.busy = true

	local torso = c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
	local hand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")

	local a, b = loadTrack(animator, ANIM.GrabA, false), loadTrack(animator, ANIM.GrabB, false)
	local hold = loadTrack(animator, ANIM.Hold, true)
	state.tracks = { a, b, hold }

	task.delay(PICKUP.GrabA, function() a:Play() end)
	task.delay(PICKUP.Grab, playSound, SOUND.Grab, torso or root)
	task.delay(PICKUP.GrabB, function() b:Play() end)
	task.delay(PICKUP.Hold, function()
		if not state.busy then return end
		hold:Play()
		-- Jukebox an die Hand schweissen sobald die Halte-Pose startet
		part.Anchored, part.CanCollide = false, false
		part.CFrame = (hand or root).CFrame * CFrame.new(0, -1, -1)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1, w.Parent = hand or root, part, part
		state.held, state.weld, state.part, state.busy = jb, w, part, false
	end)
end

local function throw()
	local c, hum, animator = character()
	if not c or not state.held or state.busy then return end
	state.busy = true
	local root = c.HumanoidRootPart
	local part, weld = state.part, state.weld
	for _, t in ipairs(state.tracks) do t:Stop(0.1) end

	local tr = loadTrack(animator, ANIM.Throw, false)
	task.delay(THROW.Anim, function() tr:Play() end)
	task.delay(THROW.Sound, function()
		playSound(SOUND.Throw, root)
		weld:Destroy()
		part.CanCollide = true
		part.AssemblyLinearVelocity = root.CFrame.LookVector * THROW_SPEED + Vector3.new(0, 20, 0)
		local hitConn
		hitConn = part.Touched:Connect(function(other)
			if other:IsDescendantOf(c) then return end
			hitConn:Disconnect()
			onHit(part)
		end)
		state.held, state.weld, state.part, state.tracks, state.busy = nil, nil, nil, {}, false
	end)
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.G then pickUp()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then throw() end
end)
