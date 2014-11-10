package uk.me.jandj.minifigcraft.items;
import cpw.mods.fml.common.FMLLog;
import cpw.mods.fml.relauncher.Side;
import cpw.mods.fml.relauncher.SideOnly;
import net.minecraft.client.model.ModelBiped;
import net.minecraft.creativetab.CreativeTabs;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityLivingBase;
import net.minecraft.item.Item;
import net.minecraft.item.ItemArmor;
import net.minecraft.item.ItemStack;
import net.minecraftforge.client.model.IModelCustom;
// note 1.8, will probably move to net.minecraftforge.model.
import net.minecraftforge.client.model.AdvancedModelLoader;
import net.minecraft.util.ResourceLocation;

/* I'd rather not inherit implementation from ItemArmor, but the comments in Item.getArmorTexture() suggests that it will only be called on instance of ItemArmor.
 */
public class LegoHelmet extends ItemArmor {
    public ItemStack inner_helmet;
    public String model_name;
    @SideOnly(Side.CLIENT)
    public IModelCustom model;
    
    // ItemArmor(ArmorMaterial, int renderIndex, int armorType);
    public LegoHelmet() {
        // super-constructor, must go first, from ItemArmor.  We don't really want to have these here, but we do need these here...
        // renderIndex selects what texture-set the renderer should use?
        super(ItemArmor.ArmorMaterial.CLOTH, /* renderIndex */ 0, /* armorType */ 0 /* helmet */);
        
        // Generic Item fields
        setMaxStackSize(1);
        setCreativeTab(CreativeTabs.tabMisc);
        setUnlocalizedName("LegoHelmet");
        bFull3D = true;
        
        // LegoHelmet's own bits.
        inner_helmet = null;
        model_name = "99243p01";
    }
    
    // Armor types: 0=helmet, 1=plate, 2=legs, 3=boots
    
    /* Methods for us to implement ourselves. */
    /* onItemUse / onItemRightClick, addInformation, isValidArmor, getArmorTexture, getArmorModel */

    /* Can entity put stack on it's armorType? */
    public boolean isValidArmor(ItemStack stack, int armorType, Entity entity) {
        // Armor types: 0=helmet, 1=plate, 2=legs, 3=boots
        return (armorType == 0);
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
    @SideOnly(Side.CLIENT)
    public ModelBiped getArmorModel(EntityLivingBase wearer, ItemStack armor, int armorSlot) {
        FMLLog.info("got getArmorModel!");
        if (model == null) {
            // Lazy-load the model
            model = AdvancedModelLoader.loadModel(new ResourceLocation("minifigcraft:models/99243p01.obj"));
        }
        FMLLog.info("Survived loading the model!");

        return null;
    }
    

    /* Methods to pass on to the innerhelmet. */
    /* getMaxDamage, setMaxDamage, isDamageable, getDamage, getDisplayDamage?, showDurabilityBar, getDurabilityForDisplay, getMaxDamage, isDamaged, setDamage */
}
