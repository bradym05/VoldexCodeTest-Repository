# VoldexCodeTest-Repository
 
Initial Gameplay Analysis:

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
-The code indexes services instead of using game:GetService(), this should be modified <br />
-Code needs to be commented to improve readability <br />

PadService:<br />

The PadPurchase event is redundant. onPadPurchased can simply be called from the line that PadPurchase is fired on. onPadPurchased also appears unnecessary,
it initalizes a "message" variable but does nothing with it.

PlayerData:<br />

I am going to entirely refactor this script. Many of the functions are redundant and I would like to save player data to DataStores.