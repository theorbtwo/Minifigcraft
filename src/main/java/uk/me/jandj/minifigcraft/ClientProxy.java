package uk.me.jandj.minifigcraft;

import uk.me.jandj.minifigcraft.blocks.render.RenderMirror;
import cpw.mods.fml.client.registry.RenderingRegistry;

public class ClientProxy extends ServerProxy {

	/* (non-Javadoc)
	 * @see uk.me.jandj.minifigcraft.ServerProxy#moreMain()
	 */
	@Override
	public void moreMain() {
		// TODO Auto-generated method stub
		super.moreMain();

		RenderingRegistry.registerBlockHandler(new RenderMirror());
	}
}
