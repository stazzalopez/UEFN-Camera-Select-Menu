using { /Fortnite.com/UI }
using { /Fortnite.com/Game }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

CameraSelectorModule := module:

	# Zone camera mapping for isometric mode
	zone_camera_config := class<concrete>:
		@editable
		Zone : mutator_zone_device = mutator_zone_device{}
		@editable
		Camera : gameplay_camera_fixed_angle_device = gameplay_camera_fixed_angle_device{}

	camera_selector_device<public> := class(creative_device):

		# Player spawners to detect when players join
		@editable
		PlayerSpawners : []player_spawner_device = array{}

		# Camera devices for TPS and Isometric views
		@editable
		TPSCamera : gameplay_camera_orbit_device = gameplay_camera_orbit_device{}

		# Isometric camera devices
		@editable
		IsometricDefaultCamera : gameplay_camera_fixed_angle_device = gameplay_camera_fixed_angle_device{}
		
		# Room mutator zone cameras (for isometric mode)
		@editable
		RoomZoneCameras : []zone_camera_config = array{}
		
		# Multi wave zone cameras (for isometric mode)
		@editable
		MultiWaveZoneCameras : []zone_camera_config = array{}
		
		# Third person controls device (always active for isometric mode)
		@editable
		ThirdPersonControls : gameplay_controls_third_person_device = gameplay_controls_third_person_device{}

		# Track which players have already chosen their camera
		var PlayerCameraChosen : [agent]logic = map{}
		
		# Track which camera mode each player selected
		var PlayerCameraMode : [agent]string = map{}

		# Track per-player canvas
		var CanvasByPlayer : [player]?canvas = map{}
		
		# Track which zone each player is currently in (for isometric mode)
		var PlayerCurrentZoneCamera : [agent]?gameplay_camera_fixed_angle_device = map{}

		TextForUI<localizes>(S : string) : message = "{S}"

		OnBegin<override>()<suspends>:void=
			# Subscribe to player spawner events
			for (PS : PlayerSpawners):
				PS.SpawnedEvent.Subscribe(OnPlayerSpawned)
			# Subscribe to room zone events
			for (ZoneConfig : RoomZoneCameras):
				ZoneConfig.Zone.AgentEntersEvent.Subscribe(OnRoomZoneEntered)
				ZoneConfig.Zone.AgentExitsEvent.Subscribe(OnRoomZoneExited)
			# Subscribe to multi wave zone events
			for (ZoneConfig : MultiWaveZoneCameras):
				ZoneConfig.Zone.AgentEntersEvent.Subscribe(OnMultiWaveZoneEntered)
				ZoneConfig.Zone.AgentExitsEvent.Subscribe(OnMultiWaveZoneExited)
			# Show selection for existing players (in case game starts with players already present)
			for (P : GetPlayspace().GetPlayers()):
				if (Ag := agent[P]):
					if (not PlayerCameraChosen[Ag]):
						ShowCameraSelection(P)

		OnPlayerSpawned(NewAgent : agent):void=
			# Only show selection if player hasn't chosen yet
			if (not PlayerCameraChosen[NewAgent]):
				if (P := player[NewAgent]):
					ShowCameraSelection(P)

		ShowCameraSelection(Target : player):void=
			if (UI := GetPlayerUI[Target]):
				# Remove old canvas if exists
				if (Tmp := CanvasByPlayer[Target]):
					if (Existing := Tmp?):
						UI.RemoveWidget(Existing)
				# Create and add new canvas
				Cv := CreateCameraSelectionCanvas()
				if (set CanvasByPlayer[Target] = option{ Cv }){}
				UI.AddWidget(Cv, player_ui_slot{ InputMode := ui_input_mode.All })

		OnTPSClicked(WidgetMessage : widget_message):void=
			if (Ag := agent[WidgetMessage.Player]):
				# Mark as chosen
				if (set PlayerCameraChosen[Ag] = true){}
				# Store camera mode
				if (set PlayerCameraMode[Ag] = "TPS"){}
				# TPS mode: don't add any camera (use default)
				# Close the UI
				CloseCameraSelection(WidgetMessage.Player)

		OnIsometricClicked(WidgetMessage : widget_message):void=
			if (Ag := agent[WidgetMessage.Player]):
				# Mark as chosen
				if (set PlayerCameraChosen[Ag] = true){}
				# Store camera mode
				if (set PlayerCameraMode[Ag] = "Isometric"){}
				# Apply default isometric camera
				IsometricDefaultCamera.AddTo(Ag)
				# Apply third person controls (always active for isometric)
				ThirdPersonControls.AddTo(Ag)
				# Close the UI
				CloseCameraSelection(WidgetMessage.Player)

		OnCloseClicked(WidgetMessage : widget_message):void=
			CloseCameraSelection(WidgetMessage.Player)

		CloseCameraSelection(Target : player):void=
			if (UI := GetPlayerUI[Target]):
				if (Tmp := CanvasByPlayer[Target]):
					if (Cv := Tmp?):
						UI.RemoveWidget(Cv)
					if (set CanvasByPlayer[Target] = false){}

		CreateCameraSelectionCanvas():canvas=
			var Slots : []canvas_slot = array{}
			# Background image 1048x607 (teleport menu style)
			BGSize := vector2{ X := 1048.0, Y := 607.0 }
			set Slots += array
			{
				canvas_slot:
					Anchors := anchors{ Minimum := vector2{ X := 0.5, Y := 0.5 }, Maximum := vector2{ X := 0.5, Y := 0.5 } }
					Offsets := margin{ Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0 }
					Alignment := vector2{ X := 0.5, Y := 0.5 }
					SizeToContent := true
					Widget := texture_block{ DefaultImage := Textures.CameraModeBG, DefaultDesiredSize := BGSize }
			}

			# Close button (top-right of the 1048x607 canvas)
			set Slots += array
			{
				canvas_slot:
					Anchors := anchors{ Minimum := vector2{ X := 0.5, Y := 0.5 }, Maximum := vector2{ X := 0.5, Y := 0.5 } }
					Offsets := margin{ Top := -BGSize.Y/2.0 + 61.0, Left := BGSize.X/2.0 - 66.0, Right := 0.0, Bottom := 0.0 }
					Alignment := vector2{ X := 0.5, Y := 0.5 }
					SizeToContent := true
					Widget := button_quiet{ DefaultText := TextForUI("X") }
			}
			if (BtnClose := button_quiet[Slots[Slots.Length-1].Widget]):
				BtnClose.OnClick().Subscribe(OnCloseClicked)

			# Buttons (teleport menu style)
			BtnSize := vector2{ X := 250.0, Y := 48.0 }
			XGap : float = 280.0

			# TPS Button (left side)
			set Slots += array
			{
				canvas_slot:
					Anchors := anchors{ Minimum := vector2{ X := 0.5, Y := 0.5 }, Maximum := vector2{ X := 0.5, Y := 0.5 } }
					Offsets := margin{ Top := 225.0, Left := -XGap - -80.0, Right := BtnSize.X, Bottom := BtnSize.Y }
					Alignment := vector2{ X := 0.5, Y := 0.5 }
					SizeToContent := false
					Widget := button_regular{ DefaultText := TextForUI("SELECT") }
			}
			if (TPSBtn := button_regular[Slots[Slots.Length-1].Widget]):
				TPSBtn.OnClick().Subscribe(OnTPSClicked)

			# Isometric Button (right side)
			set Slots += array
			{
				canvas_slot:
					Anchors := anchors{ Minimum := vector2{ X := 0.5, Y := 0.5 }, Maximum := vector2{ X := 0.5, Y := 0.5 } }
					Offsets := margin{ Top := 225.0, Left := XGap + -80.0, Right := BtnSize.X, Bottom := BtnSize.Y }
					Alignment := vector2{ X := 0.5, Y := 0.5 }
					SizeToContent := false
					Widget := button_regular{ DefaultText := TextForUI("SELECT") }
			}
			if (IsoBtn := button_regular[Slots[Slots.Length-1].Widget]):
				IsoBtn.OnClick().Subscribe(OnIsometricClicked)

			# Description text below buttons
			set Slots += array
			{
				canvas_slot:
					Anchors := anchors{ Minimum := vector2{ X := 0.5, Y := 0.5 }, Maximum := vector2{ X := 0.5, Y := 0.5 } }
					Offsets := margin{ Top := 315.0, Left := 0.0, Right := 0.0, Bottom := 0.0 }
					Alignment := vector2{ X := 0.5, Y := 0.5 }
					SizeToContent := true
					Widget := text_block{ 
						DefaultText := TextForUI("Warning:You need to re-enter the island to change the camera mode again."), 
						DefaultTextSize := 28.0, 
						DefaultTextColor := NamedColors.White, 
						DefaultShadowOffset := option{ vector2{ X := 1.5, Y := 1.5 } }, 
						DefaultShadowColor := NamedColors.Black, 
						DefaultShadowOpacity := 0.8 
					}
			}

			Canvas : canvas = canvas:
				Slots := Slots
			Canvas

		# Zone event handlers for isometric camera switching
		# Note: We need to find which zone triggered the event by checking all zones
		# This is a limitation - we'll check all room zones when any room zone event fires
		OnRoomZoneEntered(Agent : agent):void=
			# Only apply zone camera if player is in isometric mode
			# Explicitly check that mode exists and is Isometric, and NOT TPS
			if (Mode := PlayerCameraMode[Agent]):
				if (Mode = "Isometric"):
					# Find which room zone camera to use by checking all room zones
					# We'll use the first matching zone (in practice, player should only be in one)
					for (ZoneConfig : RoomZoneCameras):
						# Remove current zone camera if any
						if (CurrentCam := PlayerCurrentZoneCamera[Agent]):
							if (Cam := CurrentCam?):
								Cam.RemoveFrom(Agent)
						# Add the zone-specific camera for room zones
						ZoneConfig.Camera.AddTo(Agent)
						if (set PlayerCurrentZoneCamera[Agent] = option{ ZoneConfig.Camera }){}
						return
				# If mode is TPS, explicitly do nothing
				else if (Mode = "TPS"):
					return
			# If mode is not set, do nothing

		OnRoomZoneExited(Agent : agent):void=
			# Only handle if player is in isometric mode
			# Explicitly check that mode exists and is Isometric, and NOT TPS
			if (Mode := PlayerCameraMode[Agent]):
				if (Mode = "Isometric"):
					# Remove zone camera
					if (CurrentCam := PlayerCurrentZoneCamera[Agent]):
						if (Cam := CurrentCam?):
							Cam.RemoveFrom(Agent)
						if (set PlayerCurrentZoneCamera[Agent] = false){}
					# Restore default isometric camera
					IsometricDefaultCamera.AddTo(Agent)
				# If mode is TPS, explicitly do nothing
				else if (Mode = "TPS"):
					return
			# If mode is not set, do nothing

		OnMultiWaveZoneEntered(Agent : agent):void=
			# Only apply zone camera if player is in isometric mode
			# Explicitly check that mode exists and is Isometric, and NOT TPS
			if (Mode := PlayerCameraMode[Agent]):
				if (Mode = "Isometric"):
					# Find which multi wave zone camera to use
					for (ZoneConfig : MultiWaveZoneCameras):
						# Remove current zone camera if any
						if (CurrentCam := PlayerCurrentZoneCamera[Agent]):
							if (Cam := CurrentCam?):
								Cam.RemoveFrom(Agent)
						# Add the zone-specific camera for multi wave zones
						ZoneConfig.Camera.AddTo(Agent)
						if (set PlayerCurrentZoneCamera[Agent] = option{ ZoneConfig.Camera }){}
						return
				# If mode is TPS, explicitly do nothing
				else if (Mode = "TPS"):
					return
			# If mode is not set, do nothing

		OnMultiWaveZoneExited(Agent : agent):void=
			# Only handle if player is in isometric mode
			# Explicitly check that mode exists and is Isometric, and NOT TPS
			if (Mode := PlayerCameraMode[Agent]):
				if (Mode = "Isometric"):
					# Remove zone camera
					if (CurrentCam := PlayerCurrentZoneCamera[Agent]):
						if (Cam := CurrentCam?):
							Cam.RemoveFrom(Agent)
						if (set PlayerCurrentZoneCamera[Agent] = false){}
					# Restore default isometric camera
					IsometricDefaultCamera.AddTo(Agent)
				# If mode is TPS, explicitly do nothing
				else if (Mode = "TPS"):
					return
			# If mode is not set, do nothing

