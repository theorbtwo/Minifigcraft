package uk.me.jandj.minifigcraft.items;

import org.lwjgl.opengl.GL11;

import cpw.mods.fml.common.FMLLog;

import net.minecraft.client.model.ModelBiped;
import net.minecraft.entity.Entity;
import net.minecraftforge.client.model.IModelCustom;

public class VaugelyBiped extends ModelBiped {
	public IModelCustom model;
	public String name;

	public VaugelyBiped(IModelCustom m, String n) {
		model=m;
		name=n;
	}

    public void render(Entity ent, float swing_total, float swing_now, float time, float h_look, float v_look, float scale) {
    	FMLLog.info("render(ent, %f, %f, %f, %f, %f)", swing_total, swing_now, time, h_look, v_look, scale);
        GL11.glPushMatrix();
        GL11.glRotatef(h_look, 0, 1, 0);
        GL11.glRotatef(v_look, 1, 0, 0);
        GL11.glTranslatef(0f, -0.5f, 0f);
    	model.renderAll();
    	GL11.glPopMatrix();
    }
}
