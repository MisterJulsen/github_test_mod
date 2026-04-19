package de.mrjulsen.githubtest.forge;

import de.mrjulsen.githubtest.GithubTestMod;
import dev.architectury.platform.forge.EventBuses;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(GithubTestTmod.MOD_ID)
public final class GithubTestTmodForge {
    public GithubTestTmodForge() {
        EventBuses.registerModEventBus(GithubTestTmod.MOD_ID, FMLJavaModLoadingContext.get().getModEventBus());
        GithubTestMod.init();
    }
}
