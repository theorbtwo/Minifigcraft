/**
 *
 */
package uk.me.jandj.minifigcraft.blocks;

import uk.me.jandj.minifigcraft.blocks.render.RenderMirror;
import net.minecraft.block.Block;
import net.minecraft.block.material.Material;

/**
 * @author theorb
 *
 */
public class MirrorBlock extends Block {
	public MirrorBlock() {
		super(Material.glass);
		setBlockName("mirror");
	}

	public int getRenderType() {
		return RenderMirror.getRenderIdStatic();

	}
}
