package uk.me.jandj.minifigcraft.blocks.render;

import java.util.HashMap;
import java.util.Map;

import net.minecraft.block.Block;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.RenderBlocks;
import net.minecraft.client.renderer.entity.Render;
import net.minecraft.client.renderer.entity.RenderManager;
import net.minecraft.entity.Entity;
import net.minecraft.world.IBlockAccess;
import cpw.mods.fml.client.registry.ISimpleBlockRenderingHandler;
import cpw.mods.fml.client.registry.RenderingRegistry;

public class RenderMirror implements ISimpleBlockRenderingHandler {
	static int render_id = RenderingRegistry.getNextAvailableRenderId();

	@Override
	public void renderInventoryBlock(Block block, int metadata, int modelId,
			RenderBlocks renderer) {
		Entity looker = Minecraft.getMinecraft().thePlayer;

		Map<Class<? extends Entity>, Render> rendererMap = new HashMap<Class<? extends Entity>, Render>();

		// RenderManager.instance.renderEntitySimple(looker, 1);
	}

	@Override
	public boolean renderWorldBlock(IBlockAccess world, int x, int y, int z,
			Block block, int modelId, RenderBlocks renderer) {
		// We don't care about the metadata for this.
		renderInventoryBlock(block, 0, modelId, renderer);
		return false;
	}

	@Override
	public boolean shouldRender3DInInventory(int modelId) {
		return false;
	}

	@Override
	public int getRenderId() {
		return render_id;
	}

	public static int getRenderIdStatic() {
		return render_id;
	}
}
