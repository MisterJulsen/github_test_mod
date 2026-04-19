package de.mrjulsen.githubtest.fabric;

import de.mrjulsen.githubtest.GithubTestTmod;
import net.fabricmc.api.ModInitializer;

public final class GithubTestModFabric implements ModInitializer {
    @Override
    public void onInitialize() {
        GithubTestMod.init();
    }
}
