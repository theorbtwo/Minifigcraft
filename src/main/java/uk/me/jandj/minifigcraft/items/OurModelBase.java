package uk.me.jandj.minifigcraft.items;
import net.minecraft.client.model.ModelBase;
import net.minecraft.entity.Entity;
import net.minecraftforge.client.model.IModelCustom;

public class OurModelBase extends ModelBase {
    public IModelCustom modelCustom;

    public OurModelBase(IModelCustom mdl) {
        modelCustom = mdl;
    }

	/* (non-Javadoc)
	 * @see net.minecraft.client.model.ModelBase#render(net.minecraft.entity.Entity, float, float, float, float, float, float)
	 */
	@Override
	public void render(Entity wearer, float x, float y, float z, float roll, float pitch, float yaw) {
		// TODO Auto-generated method stub
		super.render(wearer, x, y, z, roll, pitch, yaw);
	}
}
