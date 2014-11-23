package uk.me.jandj.minifigcraft.items;
import java.io.IOException;
import java.util.List;

import cpw.mods.fml.common.FMLLog;
import cpw.mods.fml.common.registry.GameData;
import cpw.mods.fml.relauncher.Side;
import cpw.mods.fml.relauncher.SideOnly;
import net.minecraft.client.Minecraft;
import net.minecraft.client.model.ModelBiped;
import net.minecraft.client.model.ModelRenderer;
import net.minecraft.client.renderer.entity.RenderBiped;
import net.minecraft.client.renderer.entity.RenderPlayer;
import net.minecraft.client.renderer.entity.RendererLivingEntity;
import net.minecraft.client.resources.IResource;
import net.minecraft.creativetab.CreativeTabs;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityLivingBase;
import net.minecraft.entity.player.EntityPlayer;
import net.minecraft.item.Item;
import net.minecraft.item.ItemArmor;
import net.minecraft.item.ItemStack;
import net.minecraft.util.EnumChatFormatting;
import net.minecraft.util.ResourceLocation;
import net.minecraftforge.client.IItemRenderer;
//import net.minecraftforge.client.model.AdvancedModelLoader; // note 1.8, will probably move to net.minecraftforge.model.
//import net.minecraftforge.client.model.ModelFormatException;
import net.minecraftforge.client.model.IModelCustom;
import uk.me.jandj.minifigcraft.items.OurModelBase;
import uk.me.jandj.minifigcraft.obj.WavefrontObject;


/* I'd rather not inherit implementation from ItemArmor, but the comments in Item.getArmorTexture() suggests that it will only be called on instances of ItemArmor.
 */
public class LegoHelmet extends ItemArmor implements IItemRenderer {
    public ItemStack inner_helmet;
    public String model_name;
    @SideOnly(Side.CLIENT)
    public IModelCustom model;

    public LegoHelmet() {
        // super-constructor, must go first, from ItemArmor.  We don't really want to have these here, but we do need these here...
        // renderIndex selects what texture-set the renderer should use?
        // ItemArmor(ArmorMaterial, int renderIndex, int armorType);
        super(ItemArmor.ArmorMaterial.IRON, 2, 0);

        // Generic Item fields
        setMaxStackSize(1);
        setCreativeTab(CreativeTabs.tabMisc);
        setUnlocalizedName("LegoHelmet");
        bFull3D = true;

        // LegoHelmet's own bits.
        inner_helmet = new ItemStack(GameData.getItemRegistry().getObject("minecraft:iron_helmet"));
        model_name = "99243p01";
    }

    // Armor types: 0=helmet, 1=plate, 2=legs, 3=boots

    /* Methods for us to implement ourselves. */
    /* onItemUse / onItemRightClick */

    /* *Passthrough methods */
    @SideOnly(Side.CLIENT)
    public ItemArmor innerItemArmor() {
        return (ItemArmor)inner_helmet.getItem();
    }

    @SideOnly(Side.CLIENT)
    public int getColorFromItemStack(ItemStack stack, int renderPass) {
        return innerItemArmor().getColorFromItemStack(stack, renderPass);
    }

    /* Can entity put stack on it's armorType? */
    public boolean isValidArmor(ItemStack stack, int armorType, Entity entity) {
        // Armor types: 0=helmet, 1=plate, 2=legs, 3=boots
    	if (inner_helmet == null)
    		return false;

        return innerItemArmor().isValidArmor(inner_helmet, armorType, entity);
    }



    // getArmorModel, getArmorTexture
    /**
     * Override this method to have an item handle its own armor rendering.
     *
     * @param  entityLiving  The entity wearing the armor
     * @param  itemStack  The itemStack to render the model of
     * @param  armorSlot  0=head, 1=torso, 2=legs, 3=feet
     *
     * @return  A ModelBiped to render instead of the default
     */
    /*
     * While this may be obvious in-as-much-as it's clearly documented in Item.java, I have no idea
     * how we are supposed to create the ModelBiped and how it interacts with the possibility of multiple
     * pieces of armor.
     */
    @SideOnly(Side.CLIENT)
    public ModelBiped getArmorModel(EntityLivingBase wearer, ItemStack armor, int armorSlot) {
        IModelCustom model = getModel(armor);
        ModelBiped biped = new VaugelyBiped(model, model_name);
        return biped;
    }



    /* (non-Javadoc)
	 * @see net.minecraft.item.Item#getArmorTexture(net.minecraft.item.ItemStack, net.minecraft.entity.Entity, int, java.lang.String)
	 */
	@Override
	public String getArmorTexture(ItemStack stack, Entity entity, int slot,
			String type) {
		return "minifigcraft:textures/ldraw_texture.png";
	}

	@SideOnly(Side.CLIENT)
    public IModelCustom getModel(ItemStack stack) {
        if (model == null) {
            // Lazy-load the model
            model = new WavefrontObject(new ResourceLocation("minifigcraft:models/helmet/"+model_name+".obj"));
            FMLLog.info("Survived loading the model!");
        }
        return model;
    }



    /* Methods to pass on to the innerhelmet. */
    /* getMaxDamage, setMaxDamage, isDamageable, getDamage, getDisplayDamage?, showDurabilityBar, getDurabilityForDisplay, getMaxDamage, isDamaged, setDamage */

    // handleRenderType, of IItemRenderer
    public boolean handleRenderType(ItemStack item, ItemRenderType type) {
        FMLLog.info("handleRenderType(..., %s);", type);

        return false;
    }

    public boolean shouldUseRenderHelper(ItemRenderType type, ItemStack item, ItemRendererHelper helper) {
        FMLLog.info("shouldUseRenderHelper(%s, ..., %s);", type, helper);

        return false;
    }

    public void renderItem(ItemRenderType type, ItemStack item, Object... data) {
        FMLLog.info("renderItem(%s, ..., %s)", type, data);
    }

	/* (non-Javadoc)
	 * @see net.minecraft.item.Item#addInformation(net.minecraft.item.ItemStack, net.minecraft.entity.player.EntityPlayer, java.util.List, boolean)
	 */
	@Override
	@SideOnly(Side.CLIENT)
	public void addInformation(ItemStack stack, EntityPlayer player,
			List extrainfo, boolean be_verbose) {
		// Call up to our superclass.
		super.addInformation(stack, player, extrainfo, be_verbose);

		// The tooltip of our inner helmet
		List<String> inner_tooltip = inner_helmet.getTooltip(player, be_verbose);
		extrainfo.addAll(inner_tooltip);
	}

    /*
    // IRenderLivingEvent
    public void renderLivingEvent(ItemStack armorStack, EntityLivingBase entity, RendererLivingEntity renderer, double x, double y, double z) {
        FMLLog.info("renderLivingEvent");
        IModelCustom ourModel = getModel(armorStack);
        ModelBiped modelBiped;
        if (renderer instanceof RenderPlayer) {
        	modelBiped = ((RenderPlayer)renderer).modelBipedMain;
        } else if (renderer instanceof RenderBiped) {
        	modelBiped = ((RenderBiped)renderer).modelBipedMain;
        } else {
            FMLLog.info("LegoHelmet being worn by something strange -- renderer=%s", renderer);
            return;
        }
        modelBiped.bipedHeadwear = new OurModelRenderer(ourModel, "LegoHelmet");
        // This is mostly based on a mixture of random-ass guessing and iteration.
        modelBiped.bipedHeadwear.offsetY = (float) (-1.8/4);
    }*/
}
