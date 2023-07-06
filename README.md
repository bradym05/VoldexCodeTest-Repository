# VoldexCodeTest-Repository

Initial Gameplay Analysis:<br />

-In the output, many Sound objects throw the error "failed to load". These should be deleted to avoid clutter and unnecessary memory usage. <br />
-The first two buttons have no label to indicate their purpose. <br />
-The money display GUI appears underneath Roblox's CoreGui, this should be moved to somewhere more visible. <br />
-The "PlayerData" script throws the error "attempt to index nil with UserId" on line 26. <br />
-Button label stays after purchasing an item even though the button disappears. <br />
-Area behind the portal is unobtainable. <br />
-Buildings can be purchased even without sufficient funds leading to a negative money count. <br />
-On the second test run, the money counter GUI does not update. <br />

Other Notes:<br />

-ServerStorage is almost entirely unused. ReplicatedStorage should only be used for items which need to be replicated to the client. <br />
-The code indexes services instead of using game:GetService(), this should be modified. <br />
-Code needs to be commented to improve readability. <br />
-Noticed an attribute on Ship_Access_Bridge called "DisplayName" with a value of "PONTE DA BUDEGA" and removed it. <br />
-Disabled CanQuery and CanTouch on SpawnLocation. <br />
-Deleted "Building - Roblox" from workspace and ReplicatedStorage because the asset Id is invalid. <br />
-Removed unnecessary "PreviewArea" part from pads. <br />
-Enabled "TouchesUseCollisionGroups" setting from workspace for registering pad purchases. <br />
-Disabled CanQuery and CanTouch on all parts except for Pads and PaycheckMachines. <br />
-Moved money count GUI to bottom center of screen. <br />
-Redesigned money count gui. <br />
-Redesigned price label gui. <br />
-Regrouped and renamed ship parts to be purchased as part of the tycoon. <br />
-Set all RenderFidelity settings to automatic. <br />
-Turned on StreamingEnabled. <br />
-Updated CollisionFidelities and model streaming modes. <br />
-Renamed pad components. <br />
-Created sound group for game. <br />
-Created sound group for GUI. <br />
-Created new beam textures and restructured beams. <br />
-Created SetData and GetData remotes for client accessible data. <br />
-I have added my own sounds from the Toolbox. All sounds are uploaded by Roblox to avoid any copyright issues or future takedowns.<br />
-Parented interface buttons to a canvas group for hover animation.<br />
-Downloaded, modified, then imported a Sketchfab model of a floating island: https://sketchfab.com/3d-models/low-poly-little-island-a1342470050b479caf5ed79dda88414d<br />
-Replaced tycoon baseplate with floating islands.<br />
-Rotated angle of TycoonBase and Buildings to start with a pivot orientation of (0, 0, 0).<br />
-Added attribute "Ship" to all components of the pirate ship.<br />
-Downloaded vault icon from Vecteezy: https://www.vecteezy.com/vector-art/356727-vector-vault-icon<br />
-Designed paycheck button and GUI.<br />
-Imported and resized gold coins material from Sketchfab: https://sketchfab.com/3d-models/gold-coins-material-a334ce7cfb8e449391a181c2738ecd00<br />
-Imported low poly coin from Sketchfab: https://sketchfab.com/3d-models/lowpoly-gold-coin-34794c00e9d140f6b86e930fef18b009<br />
-Created coin pile mesh in blender.<br />
-Created a part "ShipPlane" and attachment "Plane" for pirate ship PlaneConstraints.<br />
-Disabled air balloon collisions, made massless, and set collision fidelity to box. <br />
-Set all mesh render fidelities to Automatic. Automatic render fidelity is actually more performant than performance. <br />
-Set up Motor6D inside of steering wheel for turning. <br />
-Created ship particles using a toolbox particle pack (https://create.roblox.com/marketplace/asset/10198615035/Reis-Particle-Pack). <br />
-Set up Motor6D inside of air balloon fan for spinning animation. <br />
-Created trails inside of ship and ship fan. <br />
-Created steering animations. <br />
-Made entire ship massless. <br />
-Removed all value objects. <br />

Generally, I use loleris' ProfileService and ReplicaService for DataStores and replication; but I decided against that for the sake of providing an accurate reflection of my abilities. I use other resources too, but the aforementioned are most relevant to this challenge. Everything provided here has been created solely for the Voldex code test and is not taken from my previous work, or anyone else's work. All of the code has been written as of 2023-06-27 or later. I am proud of my work here and I hope that it is up to par. Thank you again for this opportunity, it has been fun and exciting so far.<br />

Network ownership of pirate ships will be granted to the owner of each ship. This brings up concerns regarding security. In order to mitigate these concerns, the server will perform
checks ensuring that the ship is only moving how it is supposed to.<br />

PadService:<br />

-The PadPurchase event is redundant. onPadPurchased can simply be called from the line that PadPurchase is fired on. onPadPurchased also appears unnecessary,
it initalizes a "message" variable but does nothing with it. <br />
-I am going to convert PadService into an OOP tycoon class to enable for multiplayer. <br />

PlayerData:<br />

-The functions are too specific and most are redundant. Data does not save. <br />

(Refactored)<br />
-Data is stored as a dictionary to a single key for each user<br />
-DataStore requests are made based on the current budget, with custom yielding<br />
-Data is only saved and loaded when necessary<br />
-MemoryStoreService is used to refer UserId to a boolean value indicating if that user's data is currently saving<br />
-Players whose data is saving in another server will be kicked to prevent duplication or data loss<br />
-Error codes are retrieved and handled uniquely based on the current documentation<br />
-Active processes are counted to ensure all processes complete on BindToClose<br />
-All methods like "ArrayInsert" which change data refer back to the "SetData" method to handle all changes in one place<br />

MainHandler (was TycoonHandler) (PadService replacement): <br />

-First gets DataObjects from PlayerData for new players. <br />
-Creates tycoons from the TycoonClass module for new players. <br />
-Cleans up tycoons when players leave. <br />
-Manages a leaderstats folder for client replication. <br />
-Leaderstats are simply a reflection of data stored on the server. <br />
-Added a saving MoneyToCollect value for Paycheck Machines. <br />
-Also manages a hidden stats folder handled the same as leaderstats. <br />

-Created a tycoon template to be cloned for each player. <br />
-Seperated buildings from template to keep only one copy in memory. <br />
-Removed unnecessary "isPaycheckMachine" attribute from PaycheckMachine. <br />
-Removed "isEnabled," and "isFinished" attributes from Pads. <br />
-Created a folder named "Tycoons" to hold tycoons. <br />
-Placed the price BillboardGui in ServerStorage to clone it under each pad. <br />
-Moved buildings down to connect with ground. <br />
-Renamed buildings and pads. <br />
-Centered tycoon. <br />

-Contains a list of settings which can be modified and read by players. <br />
-Connects to remote event and function allowing players to set and read certain data. <br />
-Yields player data if not loaded using CustomSignal to prevent errors. <br />
-Ensures that only accessible data is read and written to. <br />

TycoonClass: <br />

-Creates tycoon and calculates first available slot in a variable radius and variable angle with trigonometry. <br />
-Sets pivot of all buildings to the tycoon template to ensure accurate positioning. <br />
-Sets DescendantCount attribute to all buildings for client to recognize when a building has loaded. <br />
-Loads purchased objects.<br />
-Loads pads after purchased objects to avoid unnecessary connections and keep dependencies accurate.<br />
-Sets collision group of pads to only collide with owner's character (workspace.TouchesUseCollisionGroups must stay enabled).<br />
-Slots are obtained by yielding if necessary (ex. player joins before a tycoon becomes available).<br />
-Pads are only connected to onTouched when purchaseable.<br />
-Pads are hidden in ServerStorage until needed or destroyed if not needed.<br />
-Connections are cleaned up as quickly as possible or when tycoon is destroyed.<br />
-Pads generate a price label to display price and object to player. <br />
-Underscores in object names are converted to spaces for display. <br />
-PaycheckMachine increments player's money and resets money available for collection when touched. <br />
-Player's receive their paychecks via one core loop every set interval instead of indiviudal loops for each tycoon. <br />
-Pad purchase attempts fire an event to the player to animate the pad. <br />
-Pads are destroyed after 5 seconds to give player time for animation. <br />
-If a player leaves while waiting for a slot, tycoon will cancel setup and destroy. <br />
-When tycoon is destroyed, the slot is made available again and the next in queue is notified; this ensures that slots do not become permanently unavailable. <br />
-Checks if player has purchased all ship parts, and claimed a ticket, then allows their ship to be flown. <br />
-Only unlocks ticket cabin when all other buildings have been purchased. <br />
-Creates a proximity prompt inside of the ticket cabin to claim ticket. <br />

CustomSignal:<br />

-OOP Signal Class to replace use of BindableEvents<br />
-Creates easy to use "signals"<br />
-Signals have a "Connect" method accepting a callback function and returning a connection class.<br />
-Connection class can be disconnected just like a RBXScriptConnection.<br />
-Signals can be fired to run all callback functions with any arguments.<br />
-Signals can be destroyed to disconnect all connections.<br />
-Connections can be automatically disconnected after firing using Once().<br />
-Wait can be used to connect using Once() and yield until fired with an optional MaxTime parameter.<br />

InterfaceHandler (UiHandler refactored):<br />

-Updates money count based on leaderstats. <br />
-Animates money count value on change. <br />
-Sets up buttons from the interface container frame. <br />
-Buttons open a popup frame which has the same name. <br />
-Buttons may have custom animations via children with attributes which are used as the tween goal. <br />
-Popup is closed if the open frame button is pressed again. <br />
-Popup switches frames if open and a seperate button is pressed. <br />
-Uses TweenAny, canvas group, and UIGradient to play shine animation and make open frame brighter. <br />
-Stores a brightness function for each button name to indicate which frame is open. <br />
-Uses UIStroke to make the size of active button appear larger. <br />
-Gets default GUI size of GUI objects that should change by device. <br />
-Updates GUI size and position from initial device or if device changes. <br />
-Creates a SizeConstraint if size is changed (for tweens). <br />

Animations:<br />

-Listens to event when pad is pressed.<br />
-Plays sound and pressed animation.<br />
-Tweens color of pad and beams to red if purchase fails.<br />
-Sinks pad into ground and emits coin particles if purchase succeeds.<br />
-Beams shoot upwards and fade out if purchase succeeds.<br />
-Plays purchase sound from pad.<br />

-Listens to ChildAdded in tycoon buildings folder.<br />
-Checks build animations setting.<br />
-Animates new buildings by moving them to a random location and tweening back.<br />
-Plays building sounds using QuickSound.<br />
-Tells player they must buy the ticket booth to fly their ship.<br />
-Tells player to claim ticket once they have purchased the ticket booth. <br />

QuickSound:<br />

-Module to play one time sounds and handle clean up in one place.<br />
-Takes a parent for the sound or a CFrame, or neither.<br />
-Creates a part to play sounds from if a CFrame is provided. <br />
-Attachments are created and CFramed inside of the sound part to play the sounds from (instead of creating a new part for each sound). <br />
-If no parent or CFrame is provided, sounds will be played from SoundService. <br />
-If no SoundGroup is provided, one will be assigned automatically based on where the sound is parented. <br />
-Applies default properties, if requested, for consistency. <br />
-Only creates and plays sound if group volume is greater than 0. <br />

TweenAny:<br />

-Module to "tween" instances that are not usually tweenable.<br />
-Uses a single RenderStepped connection to iterate over lerp all active tweens.<br />
-Flips start and end goal to reverse tweens if set.<br />
-Cleans up completed tweens.<br />
-Reconnects and disconnects from RunService dynamically depending on if any tweens are active.<br />

-TweenModel Method:<br />
-Returns a function to refer models to the given info in a private dictionary.<br />
-Pivots models to lerped CFrame.<br />

-TweenSequence Method:<br />
-Returns a function to refer instances to the start values and tween info in a private dictionary.<br />
-Gets values of keypoints and creates new keypoints with lerped values.<br />
-Creates a new sequence and sets original property to lerped sequence.<br />

QuickTween:<br />

-Module to do one time tweens.<br />
-Returns completed signal and destroys tweens after completion.<br />

ParticleHandler:<br />

-Stores base particle effect for use across multiple locations. <br />
-Adjusts emit counts based off of distance from camera and particle setting. <br />
-Automatically deletes created particles after use unless immediately reused in the same location. <br />

SettingsHandler:<br />

-Handles the settings popup in the main interface.<br />
-Creates a slider object for each sound group.<br />
-Creates a slider object for particle effects.<br />
-Updates volume of each sound group based on slider.<br />
-Handles boolean settings with checkboxes.<br />
-Accesses saved settings initially. <br />
-Updates settings with remote event. <br />
-Creates a settings folder inside of the player for external access. <br />
-Creates values for each setting based on the type of setting. <br />

GUI module:<br />

-Stores OOP classes for reusable Gui components.<br />

-Slider Class:<br />
-Takes image button and progress bar as parameters.<br />
-Updates progress appearance based on mouse location.<br />
-Gets changes in mouse location when held down.<br />
-Fires signal when value updates.<br />

-Button Class:<br />
-Registers a callback if provided to button press completed.<br />
-Plays click in animation and sound, click out animation and sound.<br />

InputDetection:<br />

-Detects changes in UserInputType.<br />
-Determines device by finding patterns which indicate the device of a given UserInputType.<br />
-Fires a signal when device type changes.<br />
-Stores current device.<br />

Music:<br />

-Creates a shuffled playlist from ReplicatedStorage.Sounds.Music <br />
-Plays each song until it ends and plays the next song.<br />
-Once playlist is finished, reshuffles.<br />
-Pauses music if volume is muted.<br />
-Waits until settings have loaded and all songs have loaded before playing music.<br />

PaycheckHandler:<br />

-Renders a viewport frame to visualize player's paycheck.<br />
-Creates a pile of coins relative to the size of player's paycheck.<br />
-Animates coins falling and increases pile size based on changes in paycheck.<br />
-Does not animate unless frame is open.<br />
-Creates a button object from the GUI module to request upgrades.<br />
-Animates price of upgrade on change.<br />
-Indicates purchase success or failure to the player.<br />

ShipClass:<br />

-Converts table of ship pieces into a physics assembly with weld constraints.<br />
-Does not weld parts which are already attached to the assembly.<br />
-Creates a plane constraint to prevent ships from moving up and down.<br />
-Creates linear velocity and angular velocity actuators for movement.<br />
-Mounts and dismounts players to ship via weld constraint creation/deletion.<br />
-Connects to mount requests from client and validates that requested value is not the set value.<br />
-Grants player network ownership of the ship for movement when mounted.<br />
-Revokes network ownership by anchoring the ship when dismounted.<br />
-Dismounts players on request via remote event.<br />
-Automatically resets ship to its original location when dismounted within a set range.<br />
-Calculates average velocity from given amount of checks at a given rate.<br />
-Resets ship and character if given maximum warnings are exceeded.<br />

ShipReplicator:<br />

-Disables proximity prompt.<br />
-Gets velocity actuators, and Motor6Ds.<br />
-Contains a table of tasks to be called on the Destroy method for subclasses.<br />
-Contains the private _clearDictionary method to clean up dictionaries.<br />
-Gets all particles from the ship.<br />
-Adjusts rate of particles when they are enabled based on player's particle setting.<br />
-Fades in lights and sound effect volume when they are played or enabled.<br />

PlayerShip:<br />

-Enables proximity prompt.<br />
-Listens to changes in "Mounted" attribute.<br />
-Binds movement inputs to ContextActionService when mounted and unbinds on dismount.<br />
-Tracks movement direction from inputs.<br />
-Applies movement direction to ship's linear and angular velocity on change.<br />
-Plays and changes steering animations depending on movement direction.<br />
-Turns ship wheel to move with animations.<br />
-Listens to player jump requests from UserInputService and requests dismount.<br />
-Tweens gui in and out informing player on how to stop flying the ship.<br />

ShipsClient:<br />

-Sets up existing and newly created ships.<br />
-Determines whether to create a ShipReplicator or PlayerShip object for ships.<br />
-Destroys ship objects when ship is destroying. <br />

Misc:<br />

-Sets song count attribute of Music folder to total number of songs<br />