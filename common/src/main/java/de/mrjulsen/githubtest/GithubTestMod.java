package de.mrjulsen.githubtest;

import dev.architectury.event.events.client.ClientPlayerEvent;
import net.minecraft.network.chat.Component;

public final class GithubTestMod {
    public static final String MOD_ID = "github_test_mod";

    public static void init() {
        System.out.println("Hello World!");

        ClientPlayerEvent.CLIENT_PLAYER_JOIN.register(p -> {
            p.sendSystemMessage(Component.translatable("item.testmod.dragon_scale"));
        });
    }
}
