Config = {}

Config.General = {
    
    position = {
        coords = vector3(0.0, 0.0, 0.0), -- The position of the NPC and the marker (x, y, z) /// If you want to use the NPC and the marker, you need to set enable to true
        interactionRadius = 1.5, -- The radius in which the player can interact with the NPC
        interactKey = 38, -- E key
        interactText = "Press ~INPUT_CONTEXT~ to open the cityhall",  -- Text shown when the player is in the interaction radius

        marker = {
            enable = true, -- If false, the marker will be disabled
            type = 1,  -- Marker type (https://docs.fivem.net/docs/game-references/markers/)
            scale = vector3(0.5, 0.5, 0.5), 
            color = vector3(0, 0, 255),  -- RGB SYSTEM (0-255)
            alpha = 255, -- Opacity
        },
    },

    npc = {
        enable = true, -- If false, the NPC will be disabled
        model = "a_m_m_bevhills_01", 
        heading = 0.0,
    },

}

Config.Namechange = {

    price = 1000, -- The price for a namechange
    
    item = {
        needItem = false, -- If true, the player will need the item to change his name
        itemName = "item_namechange", -- The name of the item
        itemLabel = "Namechange", -- The label of the item (shown in the inventory)
    },
    
}

Config.SocialMoney = {

    enable = true, -- If false, the social money option will be disabled   (DONT TOUCH)

    allowedJobs = { -- If empty, all jobs will be allowed /// If not empty, only the jobs in the table will be allowed /// "unemployed" will allow unemployed players
        "unemployed",
        "police",
        "ambulance",
    },

    money = {    
        payment = 1000, -- The amount of money the player will receive 
        paymentSchedule = 60, -- In minutes
        automaticMode = true, -- If true, the payment will be automatic transferred to the player's bank account /// If false, the player will need to withdraw the money
    },

    notify = {
        notify = true, -- If true, the player will be notified when the payment is received
    },

}


-- Change trigger events to your own framework or script

function clientNotify(message)
    TriggerEvent("esx:showNotification", message)
end

function serverNotify(source, message)
    TriggerClientEvent("esx:showNotification", source, message)
end
