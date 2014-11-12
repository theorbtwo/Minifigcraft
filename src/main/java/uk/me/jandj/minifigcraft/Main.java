package uk.me.jandj.minifigcraft;

import cpw.mods.fml.common.Mod.EventHandler;
import cpw.mods.fml.common.FMLLog;
import cpw.mods.fml.common.Mod;
import cpw.mods.fml.common.event.FMLInitializationEvent;
import cpw.mods.fml.common.eventhandler.SubscribeEvent;
import cpw.mods.fml.common.registry.GameRegistry;
import cpw.mods.fml.relauncher.Side;
import cpw.mods.fml.relauncher.SideOnly;
import net.minecraft.entity.EntityLivingBase;
import net.minecraft.item.ItemStack;
import net.minecraft.item.Item;
import net.minecraftforge.client.event.RenderLivingEvent;
import net.minecraftforge.common.MinecraftForge;
import uk.me.jandj.minifigcraft.items.LegoHelmet;
import uk.me.jandj.minifigcraft.items.IRenderLivingEvent;

@Mod(modid=Main.MODID, version=Main.VERSION)
public class Main {
    public static final String MODID="minifigcraft";
    public static final String VERSION="0.1";

    public static LegoHelmet helmet;

    @EventHandler
    public void init(FMLInitializationEvent event) {
        helmet = new LegoHelmet();
        GameRegistry.registerItem(helmet, "helmet");
        MinecraftForge.EVENT_BUS.register(this);


    }

    @SubscribeEvent @SideOnly(Side.CLIENT)
    public void pre(RenderLivingEvent.Pre event) {
    	FMLLog.info("In Main's RLE pre!");

        EntityLivingBase entity = event.entity;
        for (int slot=1; slot<=4; slot++) {
            // skipping slot zero, which is the in-hand slot.
            ItemStack armorStack = event.entity.getEquipmentInSlot(slot);
            if (armorStack != null) {
            	Item armorItem = armorStack.getItem();
            	FMLLog.info("armor item=%s", armorItem);
            	if (armorItem instanceof IRenderLivingEvent) {
            		FMLLog.info("Main's RLE pre found a hit, slot=%d armorItem=%s armorStack=%s entity=%s", slot, armorItem, armorStack, entity);
            		((IRenderLivingEvent)armorItem).renderLivingEvent(armorStack, entity, event.renderer, event.x, event.y, event.z);
            	}
            }
        }
    }
}
