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

TycoonHandler (PadService replacement): <br />

-Created a tycoon template to be cloned for each player. <br />
-Seperated buildings from template to keep only one copy in memory. <br />
-Removed unnecessary "isPaycheckMachine" attribute from PaycheckMachine. <br />
-Removed "isEnabled," and "isFinished" attributes from Pads. <br />
-Created a folder named "Tycoons" to hold tycoons. <br />
-Placed the price BillboardGui in ServerStorage to clone it under each pad. <br />