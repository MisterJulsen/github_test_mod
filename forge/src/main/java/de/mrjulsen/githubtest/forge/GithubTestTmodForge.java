package de.mrjulsen.githubtest.forge;

import de.mrjulsen.githubtest.GithubTestTmod;
import dev.architectury.platform.forge.EventBuses;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(GithubTestTmod.MOD_ID)
public final class GithubTestTmodForge {
    public GithubTestTmodForge() {
        // Submit our event bus to let Architectury API register our content on the right time.
        EventBuses.registerModEventBus(GithubTestTmod.MOD_ID, FMLJavaModLoadingContext.get().getModEventBus());

        // Run our common setup.
        GithubTestTmod.init();
    }
}
