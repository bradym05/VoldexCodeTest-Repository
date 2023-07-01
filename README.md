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

Generally, I use loleris' ProfileService and ReplicaService for DataStores and replication; but I decided against that for the sake of providing an accurate reflection of my abilities. I use other resources too, but the aforementioned are most relevant to this challenge. Everything provided here has been created solely for the Voldex code test and is not taken from my previous work, or anyone else's work. All of the code has been written as of 2023-06-27 or later. I am proud of my work here and I hope that it is up to par. Thank you again for this opportunity, it has been fun and exciting so far.

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

TycoonHandler (PadService replacement): <br />

-First gets DataObjects from PlayerData for new players. <br />
-Creates tycoons from the TycoonClass module for new players. <br />
-Cleans up tycoons when players leave. <br />
-Manages a leaderstats folder for client replication. <br />
-Leaderstats are simply a reflection of data stored on the server. <br />
-Added a saving MoneyToCollect value for Paycheck Machines. <br />

-Created a tycoon template to be cloned for each player. <br />
-Seperated buildings from template to keep only one copy in memory. <br />
-Removed unnecessary "isPaycheckMachine" attribute from PaycheckMachine. <br />
-Removed "isEnabled," and "isFinished" attributes from Pads. <br />
-Created a folder named "Tycoons" to hold tycoons. <br />
-Placed the price BillboardGui in ServerStorage to clone it under each pad. <br />
-Moved buildings down to connect with ground. <br />
-Renamed buildings and pads. <br />
-Centered tycoon. <br />

TycoonClass: <br />

-Creates tycoon and moves to the first available slot<br />
-Loads purchased objects<br />
-Loads pads after purchased objects to avoid unnecessary connections and keep dependencies accurate<br />
-Sets collision group of pads to only collide with owner's character (workspace.TouchesUseCollisionGroups must stay enabled)<br />
-Slots are obtained by yielding if necessary (ex. player joins before a tycoon becomes available)<br />
-Pads are only connected to onTouched when purchaseable<br />
-Pads are hidden in ServerStorage until needed or destroyed if not needed<br />
-Connections are cleaned up as quickly as possible or when tycoon is destroyed<br />
-Pads generate a price label to display price and object to player. <br />
-Underscores in object names are converted to spaces for display. <br />
-PaycheckMachine increments player's money and resets money available for collection when touched. <br />
-Player's receive their paychecks via one core loop every 5 seconds instead of indiviudal loops for each tycoon. <br />

CustomSignal:<br />

-OOP Signal Class to replace use of BindableEvents<br />
-Creates easy to use "signals"<br />
-Signals have a "Connect" method accepting a callback function and returning a connection class<br />
-Connection class can be disconnected just like a RBXScriptConnection<br />
-Signals can be fired to run all callback functions with any arguments<br />
-Signals can be destroyed to disconnect all connections<br />

InterfaceHandler (UiHandler refactored):<br />

-Updates money count based on leaderstats. <br />
-Animates money count value on change. <br />