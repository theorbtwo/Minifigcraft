package uk.me.jandj.minifigcraft.items;
import net.minecraftforge.client.event.RenderLivingEvent;
import net.minecraft.item.ItemStack;
import net.minecraft.entity.EntityLivingBase;
import net.minecraft.client.renderer.entity.RendererLivingEntity;

public interface IRenderLivingEvent {
    public void renderLivingEvent(ItemStack armorStack, EntityLivingBase entity, RendererLivingEntity renderer, double x, double y, double z);
}
