---
---
--- Script to spawn and manage groups configured in specific formations and multi-group presentations
--- As currently implemented, spawn zones are calculated as offsets from the Roosevelt
--- The characteristics of a given presentation are stored in an array of format:
---                 {presentationName, num aircraft, minimum range between spawned groups, max range, {bearings from first group}}
--- Presentations will be spawned in a selected zone and on a heading within +-10 degrees of that specified
--- Each group spawned, as well as each menu item generated are stored in tables. Elements of tables are 2D, containing a reference to an object and an index
--- Possibly this data structure is less elegant than that built into MOOSE, but I have so far been unable to implement all functions required of this script using only the tables \n
--- belonging to MOOSE classes
--- Inspiration for this script drawn from AIC classes formerly run by DCS Academy
--- C. Wild (Walrus) 2023
---

    -- Vec3 function coalition.getMainRefPoint(enum coalition.side coalition) function call returning bullseye as a Vec3

    --BASE:TraceOnOff(true)
    --BASE:TraceLevel(1)
    --BASE:TraceClass("SPAWN")
    --BASE:TraceClass("GROUP")

    --MESSAGE:New(gAircraftTypeTable[1][1]):ToAll()

    local airInterceptTrainer = {}

    --- helper functions

    -- converts value passed in from nm to metres
    local function nmToMetres(nauticalMiles)
        return (nauticalMiles * 1852)
    end

    -- converts value passed in from feet to metres
    local function ftToMetres(feet)
        return (feet * 0.3048)
    end

    -- returns a random altitude from the range passed as min and max arguments
    local function randomAltitude(min, max)
        if min == nil then
            BASE:E(tostring(gMinAltitude) .. " " .. tostring(gMaxAltitude))
            return math.random(gMinAltitude, gMaxAltitude)

        else
            BASE:E(tostring(min) .. " " .. tostring(max))
            return math.random(min, max)
        end
    end

    -- generates a random bearing from 001 to 360
    local function randomBearing()
        return math.random(1, 360)
    end

    -- returns range randomly from either optional min/max arguments or globals if no values are passed
    local function randomRange(min, max) -- called by randomDeltaX & Y to find range from centre at which group will be spawned
        if min and max ~= nil then
            return math.random(min, max) -- if arguments are passed in, range is determined between these
        else
            BASE:E("calculating deltaY from min")
            return math.random(gMinSpawnRange, gMaxSpawnRange) -- otherwise uses globals for calculation
        end
    end

    -- calculates delta x (i.e. Northing) from origin either randomly from bearing and minimum and maximum range arguments or at a fixed range if only min is passed
    local function randomDeltaX(bearing, min, max)
        if max ~= nil then
            return randomRange(min, max) * math.cos(math.rad(bearing))
        else
            BASE:E("calculating deltaX from min " .. tostring(min))
            return min * math.cos(math.rad(bearing))
        end
    end

    -- calculates delta z (i.e. Easting) from origin either randomly from bearing and minimum and maximum range arguments or at a fixed range if only min is passed
    local function randomDeltaZ(bearing, min, max)
        if max ~= nil then
            return randomRange(min, max) * math.sin(math.rad(bearing))
        else
            BASE:E("calculating deltaZ from min " .. tostring(min))
            return min * math.sin(math.rad(bearing))
        end
    end

    local function randomGroupStrength(min, max)
        return math.random(min, max)
    end

    local function bearingTo(coordFrom, coordTo)
        return coordFrom:GetAngleRadians(coordTo:GetVec3())
    end

    -- calculates the relative position of one object possessing a position from another i.e. the parameters bearingFromOrigin and separation represent the hypotenuse of the triangle /n
    -- having as its centre the object passed as origin. Returns new position as a POINT_VEC3
    function calculateOffsetPos(bearingFromOrigin, origin, separation, altitude)
        --MESSAGE:New("origin.z: " .. tostring(origin.z)):ToAll()
        local z = origin.z + (separation * math.sin(math.rad(bearingFromOrigin)))
        --MESSAGE:New("output z: " .. tostring(z)):ToAll()
        local y = randomAltitude()
        local x = origin.x + (separation * math.cos(math.rad(bearingFromOrigin)))
        local locationObj = POINT_VEC3:New(x, y, z)
        return locationObj
    end

    -- unused; calculates offset between two bearings; if 180 is passed as either argument, will calculate reciprocal
    local function bearingFrom(presentationBearing, heading)
        if presentationBearing + heading == 360 then
            return 360
        else
            return ((presentationBearing + heading) % 360)
        end
    end

    -- return location of USS Theodore Roosevelt
    function getRooseveltLocation()
        return POINT_VEC3:NewFromVec3(GROUP:FindByName("USS Theodore Roosevelt"):GetVec3())
    end

--- globals
    BASE:E("above gCentre")
    gCentre = POINT_VEC2:New(36199, 268314) -- centre from which spawn locations will be derived. Defined arbitrarily and does not couple script to a particular map. Current value corresponds roughly to centre of the Syria map
    gRoosevelt = UNIT:FindByName("USS Theodore Roosevelt")
    gRooseveltZone = ZONE_UNIT:New("Roosevelt Zone", gRoosevelt, nmToMetres(5))
    BASE:E("below gCentre")
    gBomberSpawn = ZONE:FindByName("BomberSpawn")
    gGroupSize = {1, 2}
    gMaxSpawnRange = nmToMetres(200) -- max range from gCentre at which groups can be spawned
    gMinSpawnRange = nmToMetres(100) -- min range ditto above
    gMaxAltitude = ftToMetres(32000) -- max altitude at which a group can be spawned
    gMinAltitude = ftToMetres(25000) -- min altitude ditto above
    gSpawnedCounter = 1 -- used to set index for new instances of GROUP in gPresentationTypeTable

    --- presentation, aircraft and spawned groups tables
    --- each element contains: [1] presentation name [2] number of aircraft, [3] min separation, [4] max separation, [5] table of bearings from lead to trail groups
    gPresentationTypeTable	= {{"Azimuth", 2, nmToMetres(5), nmToMetres(10), {270}},
                                 {"Range", 2, nmToMetres(5), nmToMetres(10), {180}},
                                 {"Vic", 3, nmToMetres(5), nmToMetres(10), {135, 225}},
                                 {"Ladder", 3, nmToMetres(5), nmToMetres(10), {180, 360}},
                                 {"Wall", 3, nmToMetres(5), nmToMetres(10), {90, 270}},
                                 {"Single Group", 1, 0, 0, {}},
                                 {"Echelon", 2, nmToMetres(7), nmToMetres(10), {200}},
                                 {"Champagne", 4, nmToMetres(7), nmToMetres(10), {45, 180, 315}},
                                 --[[{"2Stack"}, {"3Stack"}, {"Box"}--]]}

    gVF111Table = {"VF-111 200", "VF-111 201", "VF-111 202", "VF-111 203", "VF-111 204", "VF-111 205", "VF-111 206", "VF-111 207",
                    "VF-111 210", "VF-111 211", "VF-111 212", "VF-111 213", "VF-111 214", "VF-111 215", "VF-111 216"}

    -- elements are initialised by initSpawnZones(), into which data from table is passed and which replaces each element with a ZONE_UNIT iteratively
    gSpawnZoneTable = {{"Spawn Zone East", gRoosevelt, nmToMetres(30), 90, nmToMetres(250)},
                       {"Spawn Zone SouthEast", gRoosevelt, nmToMetres(30), 135, nmToMetres(250)},
                       {"Spawn Zone South", gRoosevelt, nmToMetres(30), 180, nmToMetres(250)},
                       --[[{"Spawn Zone South-Southwest", gRoosevelt, nmToMetres(30), 202.5, nmToMetres(250)},
                       {"Spawn Zone Southwest", gRoosevelt, nmToMetres(30), 225, nmToMetres(250)},
                       {"Spawn Zone West", gRoosevelt, nmToMetres(30), 270, nmToMetres(250)},--]]
                       {"Spawn Zone North", gRoosevelt, nmToMetres(30), 360, nmToMetres(250)}}

    gAircraftTypeTable = {--[[{"F-4", "fighter", "blue"}, {"F-5", "fighter", "blue"}, {"F-14", "fighter", "blue"},
                          {"F-15", "fighter", "blue"}, {"F-16", "fighter", "blue"}, {"F-18", "fighter", "blue"},--]]
                          {"Bear", "bomber", "red"}, {"Backfire", "bomber", "red"}, {"Badger", "bomber", "red"},
                          {"Farmer", "fighter", "red"}, {"Fishbed", "fighter", "red"}, {"Flogger", "fighter", "red"},
                          {"Foxbat", "fighter", "red"}, {"Fulcrum", "fighter", "red"}, {"Flanker", "fighter", "red"},
                          {"Foxhound", "fighter", "red"}, {"B-52", "bomber", "blue"}, {"B-1", "bomber", "blue"}}

    gSpawnHeadingTable = {360, 45, 90, 135, 180, 270, 315}
    gAltTable = {"Low", "Medium", "High"}
    gROETable = {{"WEAPONS FREE", 0}, {"RETURN FIRE", 3}, {"WEAPON HOLD", 4}}
    gROTTable = {{"NO REACTION", 0}, {"PASSIVE DEFENCE", 1}, {"EVADE FIRE", 2}, {"BYPASS AND ESCAPE", 3}, {"ALLOW ABORT MISSION", 4}}
    gECMTable = {{"NEVER USE", 0}, {"USE ONLY IF LOCKED BY RADAR", 1}, {"USE ONLY IF RADAR SCAN DETECTED", 2}, {"ALWAYS ON", 3}}
    gSpawnedTable = {}  -- will be filled with instances of GROUP objects as they are instantiated by spawnGroup function
    gSpawnMenuTable = {}
    gTypeMenuTable = {}
    gZoneMenuTable = {}
    gAltMenuTable = {}
    gBearingMenuItems = {}
    gGroupMenuTable = {} -- will contain menu instances to control all alive groups

    --- further helper functions requiring access to global variables
    -- generates spawn zones from parameters defined in each element of gSpawnZoneTable
    function initSpawnZones(zoneTable, lRho, lTheta)
        for i = 1, #gSpawnZoneTable do
            local tempZone = ZONE_UNIT:New(gSpawnZoneTable[i][1], gSpawnZoneTable[i][2], gSpawnZoneTable[i][3],
                    {rho = nmToMetres(200), theta = gSpawnZoneTable[i][4], relative_to_unit = false})
            gSpawnZoneTable[i] = tempZone
            --gSpawnZoneTable[i]:DrawZone(-1, {1, 0, 0}, 1, {1, 0, 0}, 0.15, 1, true) -- draws a red circle bounding generated spawn zones
        end
    end

    local function getRandomSpawnZone()
        return gSpawnZoneTable[math.random(1, #gSpawnZoneTable)]
    end

    local function setGroupSize(groupSize)
        if groupSize ~= nil then
            return groupSize
        else
            return (math.random(1, 2))
        end
    end

    -- randomly returns a string containing a group name (these MUST conform with group names in ME)
    -- optional argument allows classes of aircraft (i.e. bomber, fighter etc.) to be specified
    -- if class argument is passed and initial selection does not match, function will recur
    local function getRandomAircraft(class, side)    -- this function is desperate need of refactor; very ugly
        local selection = math.random(#gAircraftTypeTable)
        for i = 1, selection do
            if i == selection then
                if class ~= nil and side ~= nil then
                    if gAircraftTypeTable[i][2] == class and gAircraftTypeTable[i][3] == side then
                        return gAircraftTypeTable[i][1]
                    else
                        return getRandomAircraft(class, side)
                    end
                elseif class ~= nil and side == nil then
                    if gAircraftTypeTable[i][2] == class then
                        return gAircraftTypeTable[i][1]
                    else
                        return getRandomAircraft(class)
                    end
                elseif class == nil and side ~= nil then
                    if gAircraftTypeTable[i][3] == side then
                        return gAircraftTypeTable[i][1]
                    else
                        return getRandomAircraft(nil, side)
                    end
                else
                    return gAircraftTypeTable[i][1]
                end
            end
        end
    end

    local function aircraftIsClass(typeTableElement, class)
        --MESSAGE:New(typeTableElement[2]):ToAll()
        if typeTableElement[2] == class or class == nil then return true
        else return false
        end
    end

    local function aircraftIsSide(typeTableElement, side)
        --MESSAGE:New(typeTableElement[2]):ToAll()
        if typeTableElement[3] == side or side == nil then return true
        else return false
        end
    end

    -- if no argument passed, returns a random aircraft type
    -- iteratively compares argument with elements of table holding aircraft types and returns match
    local function selectType(type, class, side)
        BASE:E("selectType")
        if type == nil then
            return getRandomAircraft(class, side)
        else
            for i = 1, #gAircraftTypeTable do
                if type == gAircraftTypeTable[i][1] then
                    return type
                end
            end
        end
    end

    local function buildTypeOfClassSideTable(class, side)
        local tableSize = 1
        local tempTypeTable = {}
        for i = 1, #gAircraftTypeTable do
            if aircraftIsClass(gAircraftTypeTable[i], class) and aircraftIsSide(gAircraftTypeTable[i], side) then
                tempTypeTable[tableSize] = gAircraftTypeTable[i][1]
                tableSize = tableSize + 1
                --MESSAGE:New(tostring(tableSize)):ToAll()
            end
        end
        return tempTypeTable
    end

    --- helper functions for spawning groups
    --calculates random location and returns it as a POINT_VEC3 from origin, min and max range and bearing from origin arguments
    local function getRandomLocation(centre, min, max, bearing)
        local x = centre.x + randomDeltaX(bearing, min, max)
        local y = randomAltitude()
        local z = centre.y + randomDeltaZ(bearing, min, max)
        local locationObj = POINT_VEC3:New(x, y, z)
        return locationObj
    end

    -- conditional statements used to determine altitude band to return
    -- if no argument is passed, returns random altitude
    local function setAltitude(altString)
        if altString == "Low" then
            --MESSAGE:New("Low Altitude"):ToAll()
            return randomAltitude(ftToMetres(5000), ftToMetres(10000))
        elseif altString == "Medium" then
            --MESSAGE:New("Medium Altitude"):ToAll()
            return randomAltitude(ftToMetres(15000), ftToMetres(25000))
        elseif altString == "High" then
            --MESSAGE:New("High Altitude")
            return randomAltitude(ftToMetres(25000), ftToMetres(35000))
        else
            --MESSAGE:New("randomAltitude"):ToAll()
            return randomAltitude()
        end
    end

    -- takes a ZONE and altitude argument
    -- returns POINT_VEC3 randomly from within ZONE and sets altitude (POINT_VEC3.Y)
    local function selectLocationInZone(zone, altitude)
        local spawnLocation = zone:GetRandomPointVec3()
        spawnLocation:SetY(altitude)
        return spawnLocation
    end

    -- returns a heading +-10 degrees of passed value
    local function setHeading(baseHeading)
        return (baseHeading + math.random(-10, 10))
    end

    -- helper function for spawnPresentation() - checks if a location has been passed and randomly generates one if not
    local function checkLocation(location)
        if location == nil then
            return getRandomLocation(gCentre, gMinSpawnRange, gMaxSpawnRange, randomBearing())
        else
            return location
        end
    end

    -- helper function for spawnPresentation() - checks if a heading has been passed and randomly generates one if not
    local function checkHeading(heading)
        if heading == nil then
            return randomBearing()
        else
            return heading
        end
    end

    --- menu helper functions
    ------- Debugging of removeAll required
    function deleteGroupMenu(index)
        --MESSAGE:New("inside deleteGroupMenu"):ToAll()
        for i = 1, #gGroupMenuTable do
            if index == gGroupMenuTable[i][1] then
                for j = #gGroupMenuTable[i], 2, -1 do
                    if gGroupMenuTable[i][j] ~= nil then
                        gGroupMenuTable[i][j]:Remove()
                    end
                end
            end
        end
        --MESSAGE:New("deleteGroupMenu end of block"):ToAll()
    end

    -- iteratively deletes all spawned groups and associated menus
    function removeAll()
        for i = 1, #gSpawnedTable do
            local tempIndex = gSpawnedTable[i][2]
            if gSpawnedTable[i][1] ~= nil then
                gSpawnedTable[i][1]:Destroy(false, 1)
                groupOptionsMenu:Refresh()
            end
            if gGroupMenuTable[i][1] ~= nil then
                deleteGroupMenu(i)
            end
        end
    end

    -- index for each group object and for the table holding its particular menus is iteratively searched for a match
    -- index is passed in by menu option generated when group was instantiated
    -- calls GROUP type's Destroy function to delete instance if found
    function deleteSingleGroup(index)
        for i = 1, #gSpawnedTable do
            if gSpawnedTable[i][2] == index then
                gSpawnedTable[i][1]:Destroy(false, 1)
            end
        end
        if gGroupMenuTable[index][1] ~= nil then
            --deleteGroupMenu(index)
        end
        collectgarbage()
    end

    local function isGroup(lGroup)
        -- check if a group stored in gSpawnedTable is the group returned by another function
        -- return group index
    end

    local function cleanUpDeadGroups()
        -- if a group has been destroyed entirely, call deleteGroupMenu for that group
    end

    --- helper functions for changing ROE, RoT and ECM use
    -- all called from procedurally-generated group menu
    -- arguments are initialised by menu constructor and passed when function is called
    -- value passed in is the enum for the selected option
    function setROE(thisGroup, ROEVal)
        thisGroup:OptionROE(ROEVal)
    end

    function setROT(thisGroup, ROTVal)
        thisGroup:OptionROT(ROTVal)
    end

    function setECMUse(thisGroup, ECMVal)
        if ECMVal == 3 then
            thisGroup:OptionECM_AlwaysOn()
        elseif ECMVal == 2 then
            thisGroup:OptionECM_DetectedLockByRadar()
        elseif ECMVal == 1 then
            thisGroup:OptionECM_OnlyLockByRadar()
        else
            thisGroup:OptionECM_Never()
        end
    end

    --- functions called to instantiate new groups
    -- helper function using calculateOffsetPos() to set a waypoint for group argument on the passed bearing
    local function setWaypointFromOffset(group, bearing, origin, speed, range)
        BASE:E("setWaypoint")
        local newWaypoint = calculateOffsetPos(bearing, origin, 250000)
        group:RouteAirTo(newWaypoint:GetCoordinate(), POINT_VEC3.RoutePointAltType.BARO, POINT_VEC3.RoutePointType.TurningPoint,
                POINT_VEC3.RoutePointAction.TurningPoint, 800, 1)
        BASE:E("waypoint set")
    end

    -- creates a new waypoint for group passed in from the location of another unit or static passed as second argument
    local function setWaypointFromUnitLocation(group, waypointUnitLocation, altitude)
        local newWaypoint = waypointUnitLocation:GetCoordinate()
        newWaypoint:SetY(setAltitude(altitude))
        group:RouteAirTo(newWaypoint:GetCoordinate(), POINT_VEC3.RoutePointAltType.BARO, POINT_VEC3.RoutePointType.TurningPoint,
                POINT_VEC3.RoutePointAction.TurningPoint, 800, 1)
    end

    -- determines whether new waypoint will be initialised using an offset or the location of a unit or static, then
    -- calls appropriate function
    local function setWaypointHelper(group, bearing, origin, waypointUnitLocation, altitude)
        if waypointUnitLocation ~= nil then
            setWaypointFromUnitLocation(group, waypointUnitLocation, altitude)
        else
            setWaypointFromOffset(group, bearing, origin)
        end
    end

    -- tests whether group has been destroyed and returns boolean or nil depending on status
    local function isGroupAlive(groupIndex)
        return gSpawnedTable[groupIndex][1]:IsAlive()
    end

    -- if isGroupAlive returns nil, calls deleteGroupMenu for destroyed group
    local function groupDestroyedHelper(groupIndex, timer)
        if isGroupAlive(groupIndex) == nil then
            --MESSAGE:New(tostring(groupIndex)):ToAll()
            deleteGroupMenu(groupIndex)
            --timer:Stop()
        end
    end

    local function newGroupTimer(group, index)

    end

    -- spawns group with characteristics set by arguments gathered from multi-layered menu
    -- altitude is passed in as a string, then passed to setAltitude function which determines a random value within bands defined in gAltTable
    -- if the new group is desired to be spawned on a heading toward another unit or static, the location of that object is passed
    -- the third element of the table generated by this function is a timer calling groupDestroyedHelper, which tests for the destruction of the group
    function spawnGroup(location, heading, type, altitude, groupSize, waypointUnitLocation)
        local newGroup = SPAWN:NewWithAlias(type, "AIC Group " .. type .. " " .. tostring(gSpawnedCounter))
        location:SetY(setAltitude(altitude))
        --MESSAGE:New(tostring(location:GetY())):ToAll()
        newGroup:InitHeading(heading)
        newGroup:InitGroupHeading(heading)
        newGroup:InitGrouping(setGroupSize(groupSize))
        BASE:E("table not empty")
        gSpawnedTable[gSpawnedCounter] = {newGroup:SpawnFromPointVec3(location), gSpawnedCounter,
                                          TIMER:New(groupDestroyedHelper, gSpawnedCounter):Start(0, 0.5)}
        gGroupMenuTable[gSpawnedCounter] = buildGroupMenu(gSpawnedTable[gSpawnedCounter][1]), setWaypointHelper(gSpawnedTable[gSpawnedCounter][1],
                heading, location, waypointUnitLocation, altitude)
        --gGroupMenuTable[gSpawnedCounter]:HandleEvent(EVENTS.Dead)
        gSpawnedCounter = gSpawnedCounter + 1
        --BASE:E(gSpawnedTable[gSpawnedCounter]:GetPositionVec3())
        return gSpawnedTable[gSpawnedCounter - 1]
    end

    -- spawns first group in a presentation (via spawnGroup()) and iteratively spawns remaining groups in presentation
    function spawnPresentation(selectedPresentation, type, origin, groupHeadingArg, altitude, groupSize)
        --BASE:E("spawnPresentation")
        local leadPosition = checkLocation(origin)
        local groupHeading = checkHeading(groupHeadingArg)
        local separation = randomRange(selectedPresentation[3], selectedPresentation[4])
        spawnGroup(leadPosition, groupHeading, type, altitude, groupSize)
        for i = 1, #selectedPresentation[5] do
            local angleOff = selectedPresentation[5][i] + groupHeading
            spawnGroup(calculateOffsetPos(angleOff, leadPosition, separation), groupHeading, type, altitude, groupSize)
        end
        --MESSAGE:New(selectedPresentation[2] .. "-group " .. selectedPresentation[1] .. " presentation spawned"):ToAll()
    end

    function spawnAICPresHelper(presentation, type, zone, altitude, heading, groupSize)
        spawnPresentation(presentation, selectType(type), selectLocationInZone(zone), setHeading(heading), altitude, groupSize)
    end

    --- Build F10 Menu for spawning new presentations
    function buildPresentationMenu()
        menuAIC = MENU_COALITION:New(coalition.side.BLUE, "Manage Groups and Presentations") -- top level menu (under F10)
        spawnMenu = MENU_COALITION:New(coalition.side.BLUE, "Spawn a New Presentation")
        local menuItemPresentation
        local menuItemType
        local menuItemZone
        local menuItemAltitude
        local menuItemHeading
        for i = 1, #gPresentationTypeTable do
            menuItemPresentation = MENU_COALITION:New(coalition.side.BLUE,
                    "Spawn " .. tostring(gPresentationTypeTable[i][2]) .. "-Group " .. gPresentationTypeTable[i][1] .. "...", spawnMenu)
            gSpawnMenuTable[i] = menuItemPresentation
            for j = 1, #gAircraftTypeTable do
                menuItemType = MENU_COALITION:New(coalition.side.BLUE, gAircraftTypeTable[j][1] .. "...", menuItemPresentation)
                gTypeMenuTable[j] = menuItemType
                for k = 1, #gSpawnZoneTable do
                    menuItemZone = MENU_COALITION:New(coalition.side.BLUE, "Spawn in " .. gSpawnZoneTable[k]:GetName() .. "...", menuItemType)
                    gZoneMenuTable[k] = menuItemZone
                    for l = 1, #gAltTable do
                        menuItemAltitude = MENU_COALITION:New(coalition.side.BLUE, "Spawn at " .. gAltTable[l] .. " altitude...", menuItemZone)
                        gAltMenuTable[l] = menuItemAltitude
                        for m = 1, #gSpawnHeadingTable do
                            menuItemHeading = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Set Spawn Heading " .. tostring(gSpawnHeadingTable[m]) .. "...", menuItemAltitude,
                                    spawnAICPresHelper, gPresentationTypeTable[i], gAircraftTypeTable[j][1], gSpawnZoneTable[k], gAltTable[l], gSpawnHeadingTable[m])
                            gBearingMenuItems[m] = menuItemHeading
                        end
                    end
                end
            end
        end
        --deleteMenu = MENU_COALITION:New(coalition.side.BLUE, "Delete Groups...", menuAIC) -- temporarily disabled
        --deleteAllMenu = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Delete All Groups", deleteMenu, removeAll) -- temporarily disabled due to bug resulting in called fn not working under some circumstances
        deleteSingleMenu = MENU_COALITION:New(coalition.side.BLUE, "Delete a Group...", menuAIC) -- parent menu temporarily set as AIC top menu vice deleteMenu
        groupOptionsMenu = MENU_COALITION:New(coalition.side.BLUE, "Set Group Options...", menuAIC)
    end

    --- build menu to control group behaviour - menu items to delete group, change ROE, ROT and ECM use
    function buildGroupMenu(thisGroup)
        local index = gSpawnedCounter
        local tempGroupMenu = MENU_COALITION:New(coalition.side.BLUE, "Manage " .. thisGroup:GetName() .. "...", groupOptionsMenu)
        local tempROEMenu = MENU_COALITION:New(coalition.side.BLUE, "Set ROE...", tempGroupMenu)
        local tempROTMenu = MENU_COALITION:New(coalition.side.BLUE, "Set ROT...", tempGroupMenu)
        local tempECMMenu = MENU_COALITION:New(coalition.side.BLUE, "Set ECM Use...", tempGroupMenu)
        local tempDeleteMenu = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Delete " .. thisGroup:GetName() .. "...", deleteSingleMenu, deleteSingleGroup, index)
        local menuSet = {index, tempGroupMenu, tempROEMenu, tempROTMenu, tempECMMenu, tempDeleteMenu}
        for i = 1, #gROETable do
            menuSet[#menuSet + i] = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Set ROE " .. gROETable[i][1], menuSet[3], setROE, thisGroup, gROETable[i][2])
        end
        for j = 1, #gROTTable do
            menuSet[#menuSet + j] = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Set ROT " .. gROTTable[j][1], menuSet[4], setROT, thisGroup, gROTTable[j][2])
        end
        for k = 1, #gECMTable do
            menuSet[#menuSet + k] = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Set ECM Use " .. gECMTable[k][1], menuSet[5], setECMUse, thisGroup, gECMTable[k][2])
        end
        return menuSet
    end

    -- currently unused helper functions for planned refactor of menu generation functions
    local function checkIsCommandMenu(isCommandMenu)
        if isCommandMenu == true then
            return MENU_COALITION_COMMAND
        else
            return MENU_COALITION
        end
    end

    local function buildMenuItem(isCommandMenu, menuText, menuFunction, menuArguments)
        return checkIsCommandMenu(isCommandMenu):New(coalition.side.blue, menuText, menuFunction, menuArguments)
    end

    local function buildSubMenu(menuData, isCommandMenu, menuText, menuFunction, menuArguments)
        local tempMenu = {}
        for i = 1, #menuData do
            tempMenu[i] = buildMenuItem(isCommandMenu, menuText, menuFunction, menuArguments)
        end
        return tempMenu
    end


    ---functions to modify group behaviour
    local function bogeyCourseChange(bogeyGroup)

        --local bogeyEscortZones = setBogeyTriggerZones()
        -- if bomber has detected fighter radar, randomly determine change of course up to 60 degrees
        -- start timer of randomly determined duration which will return bomberGroup to heading to original waypoint
        -- after return to heading for original waypoint, timer starts for a further course change if fighter radar is still detected
    end

    local function bogeyReturnToCourse(bogeyGroup)
        -- return bogey to original course (e.g. toward the CVBG or an airbase)
    end

    local function bogeyManoeuvreAggressive(fighterGroup, bogeyGroup)
        -- if fighter is within closeEscortZone, randomly determine if bogey will attempt an aggressive manoeuvre (e.g. hard turn into fighter)
    end

    local function bogeyGoHome(fighterGroup, bogeyGroup)
        -- if fighter is within close escort or close in zone, timer starts which will make a random check at intervals to RTB bogey
    end

--- Fleet Defence Trainer
--- Spawns 1 - 3 groups of bombers at a given range and bearing from a centre point (by default the Roosevelt)
--- The number of groups can be selected or randomised
--- spawn of latter groups may be delayed
--- groups may make random heading changes
--- layered zones around units trigger timed conditional checks to randomly determine post-intercept behaviour of bombers
--- bombers may aggressively manoeuvre against fighters and make rapid speed/altitude changes
--- Built upon basic Air Intercept Trainer
--- under investigation: speech recognition to enable some degree of radio comm with intruders

    -- creates trigger zones around lead unit in group
    local function setBogeyTriggerZones(bogeyGroup)
        --local leadUnit = bogeyGroup[1]:GetFirstUnit()
        --MESSAGE:New(tostring(leadUnit:GetFuel())):ToAll()
        local zoneTable = {}
        zoneTable[1] = ZONE_GROUP:New("close in zone", bogeyGroup[1], ftToMetres(90)) -- creates a zone of r = 90' around lead unit in group
        zoneTable[2] = ZONE_GROUP:New("close escort zone", bogeyGroup[1], ftToMetres(120)) -- creates zone r = 120' around unit
        zoneTable[3] = ZONE_GROUP:New("too far zone", bogeyGroup[1], ftToMetres(250))
        --zoneTable[3]:DrawZone(-1, {1, 0, 0}, 1, {1, 0, 0}, 0.15, 1, true)
        return zoneTable
    end

    local function fleetDefenceTrainerHelper(bomberType)
        spawnLocation = selectLocationInZone(getRandomSpawnZone())
        local tempGroup = spawnGroup(spawnLocation, bearingTo(spawnLocation, getRooseveltLocation()), bomberType, "Medium", nil, getRooseveltLocation())
        setBogeyTriggerZones(tempGroup)
    end

    local function buildBomberSelectMenu(side)
        tempInterceptMenu = {}
        tempTypeTable = buildTypeOfClassSideTable("bomber", "blue")
        --MESSAGE:New(tostring(#tempTypeTable)):ToAll()
        for i = 1, #tempTypeTable do
            tempInterceptMenu[i] = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Spawn " .. tempTypeTable[i] .. "...",
                    fleetDefenderTrainerMenu, fleetDefenceTrainerHelper, tempTypeTable[i])
        end
        tempInterceptMenu[#tempInterceptMenu + 1] = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Spawn Random Type...",
                fleetDefenderTrainerMenu, fleetDefenceTrainerHelper, selectType(nil, "bomber", "blue"))
        return tempInterceptMenu
    end

    local function fleetDefenceTrainerMenu()
        fleetDefenderTrainerMenu = MENU_COALITION:New(coalition.side.BLUE, "Fleet Defence Trainer")
        fleetDefenceMenuTimer = TIMER:New(buildBomberSelectMenu):Start(5, 15)
        fleetDefenceRefreshTimer = TIMER:New(fleetDefenderTrainerMenu:Refresh()):Start(5, 15)
    end

    local function fleetDefenceTrainer()
        fleetDefenceTrainerMenu()
    end

    --- Intercept Trainer
    --- Spawns a single aircraft 100nm from client at a set bearing and set TA on which to practice stern conversion intercepts
    local function interceptTrainerHelper(Client, spawnZone, targetHeading)
        local spawnLocation = selectLocationInZone(spawnZone)
        spawnGroup(spawnLocation, targetHeading, "B-52", "medium", 1)
    end

    --[[local function interceptTrainer()
        local Client_SET = SET_CLIENT:New():FilterActive(Active):FilterPrefixes("VF-111"):FilterStart()
        MESSAGE:New(tostring(#Client_SET)):ToAll()
        Client_SET:ForEachClient(
        function(Client)
            local fighter = Client:GetUnits()
            local playerName = Client:GetPlayerName()
            local targetSpawnZone = ZONE_UNIT:New("Intercept Target Spawn Zone", fighter, nmToMetres(15), {rho = nmToMetres(100), theta = 360, relative_to_unit = true})
            local interceptTrainerTopMenu = MENU_GROUP:New(Grp, "Intercept Trainer")
            local clientMenuTable = {}
            for i = 1, #gSpawnHeadingTable do
                clientMenuTable[i] = MENU_GROUP_COMMAND:New(Client:GetGroup(), "Spawn Intercept Target on heading " .. tostring(#gSpawnHeadingTable[i]),
                        interceptTrainerTopMenu, Client, targetSpawnZone, interceptTrainerHelper, Client, targetSpawnZone, gSpawnHeadingTable[i])
            end
        end)
    end--]]

    --- air to air range
    --- spawns hostile fighters in a specified zone
    --- supports the calling of multiple presentations and multi-aircraft groups

    local function airToAirRangeHelper(groupType, altitude, groupSize, groupFormation)
        spawnAICPresHelper(gPresentationTypeTable[6], groupType,  ZONE:FindByName("A-A Start Zone"), altitude, 360, groupSize)
    end

    local function buildAirToAirRangeMenu()
        airToAirRangeTopMenu = MENU_COALITION:New(coalition.side.BLUE, "Air to Air Range")
        airToAirRangeTypeMenu = {}
        airToAirRangeFlightSizeMenu = {}
        airToAirRangeAltMenu = {}
        local typeTable = buildTypeOfClassSideTable("fighter")
        for i = 1, #typeTable do
            airToAirRangeTypeMenu[i] = MENU_COALITION:New(coalition.side.BLUE, typeTable[i], airToAirRangeTopMenu)
            for j = 1, 4 do
                airToAirRangeFlightSizeMenu[j] = MENU_COALITION:New(coalition.side.BLUE, tostring(j) .. " ship flight", airToAirRangeTypeMenu[i])
                for k = 1, #gAltTable do
                    airToAirRangeAltMenu[k] = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Spawn flight at " .. gAltTable[k] .. " altitude",
                            airToAirRangeFlightSizeMenu[j], airToAirRangeHelper, typeTable[i], gAltTable[k], j)
                end
            end
        end
        return airToAirRangeTypeMenu, airToAirRangeFlightSizeMenu, airToAirRangeAltMenu
    end

    local function airToAirRange()
        buildAirToAirRangeMenu()
    end

    function main()
        initSpawnZones()
        buildPresentationMenu()
        fleetDefenceTrainer()
        airToAirRange()
        --interceptTrainer()
        return 0
    end

    main()