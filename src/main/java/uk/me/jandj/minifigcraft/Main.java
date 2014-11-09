package uk.me.jandj.minifigcraft;

import cpw.mods.fml.common.Mod.EventHandler;
import cpw.mods.fml.common.Mod;
import cpw.mods.fml.common.event.FMLInitializationEvent;
import cpw.mods.fml.common.registry.GameRegistry;
import uk.me.jandj.minifigcraft.items.LegoHelmet;

@Mod(modid=Main.MODID, version=Main.VERSION)
public class Main {
    public static final String MODID="minifigcraft";
    public static final String VERSION="0.1";

    public static LegoHelmet helmet;

    @EventHandler
    public void init(FMLInitializationEvent event) {
        helmet = new LegoHelmet();
        GameRegistry.registerItem(helmet, "helmet");
    }
}
