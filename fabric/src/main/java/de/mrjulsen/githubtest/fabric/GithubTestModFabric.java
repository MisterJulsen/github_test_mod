package de.mrjulsen.githubtest.fabric;

import de.mrjulsen.githubtest.GithubTestMod;
import net.fabricmc.api.ModInitializer;

public final class GithubTestModFabric implements ModInitializer {
    @Override
    public void onInitialize() {
        GithubTestMod.init();
    }
}
