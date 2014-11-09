package uk.me.jandj.minifigcraft.items;
import net.minecraft.item.ItemArmor;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.creativetab.CreativeTabs;
import net.minecraft.entity.Entity;

/* I'd rather not inherit implementation from ItemArmor, but the comments in Item.getArmorTexture() suggests that it will only be called on instance of ItemArmor.
 */
public class LegoHelmet extends Item {
    public ItemStack inner_helmet;
    public String model_name;
    
    // ItemArmor(ArmorMaterial, int renderIndex, int armorType);
    public LegoHelmet() {
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
    

    /* Methods to pass on to the innerhelmet. */
    /* getMaxDamage, setMaxDamage, isDamageable, getDamage, getDisplayDamage?, showDurabilityBar, getDurabilityForDisplay, getMaxDamage, isDamaged, setDamage */
}
