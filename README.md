# VoldexCodeTest-Repository
 
Initial Gameplay Analysis:

-In the output, many Sound objects throw the error "failed to load". These should be deleted to avoid clutter and unnecessary memory usage.
-The first two buttons have no label to indicate their purpose.
-The money display GUI appears underneath Roblox's CoreGui, this should be moved to somewhere more visible.
-The "PlayerData" script throws the error "attempt to index nil with UserId" on line 26.
-Button label stays after purchasing an item even though the button disappears.
-Area behind the portal is unobtainable.
-Buildings can be purchased even without sufficient funds leading to a negative money count.
-On the second test run, the money counter GUI does not update.