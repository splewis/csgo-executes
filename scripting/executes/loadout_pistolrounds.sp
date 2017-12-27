public void PistolRounds_Assign(ArrayList tPlayers, ArrayList ctPlayers, Bombsite site) {
  for (int i = 0; i < tPlayers.Length; i++) {
    AssignT(tPlayers.Get(i));
  }

  for (int i = 0; i < ctPlayers.Length; i++) {
    AssignCT(ctPlayers.Get(i));
  }
}

static void AssignCT(int client) {
  g_PlayerKit[client] = false;
  g_PlayerArmor[client] = 100;
  g_PlayerHelmet[client] = false;
  g_PlayerPrimary[client] = "";
  g_PlayerSecondary[client] = "weapon_hkp2000";

  if (Chance(0.2)) {
    g_PlayerKit[client] = true;
    g_PlayerArmor[client] = 0;
    if (Chance(0.5))
      g_PlayerNades[client] = "s";
    else
      g_PlayerNades[client] = "ff";
  }
}

static void AssignT(int client) {
  int spawn = g_SpawnIndices[client];
  bool throwingSetNade = IsGrenade(g_SpawnGrenadeTypes[spawn]);

  g_PlayerArmor[client] = 100;
  g_PlayerHelmet[client] = false;
  g_PlayerPrimary[client] = "";
  g_PlayerSecondary[client] = "weapon_glock";

  if (throwingSetNade) {
    g_PlayerArmor[client] = 0;
    float f = GetRandomFloat();
    if (f < 0.30) {
      g_PlayerSecondary[client] = "weapon_glock";
      g_PlayerNades[client] = "ff";

    } else if (f < 0.6) {
      g_PlayerSecondary[client] = "weapon_glock";
      g_PlayerNades[client] = "";

    } else if (f < 0.8) {
      GiveUpgradedSecondary(client, CS_TEAM_T);
      g_PlayerNades[client] = "";

    } else {
      g_PlayerSecondary[client] = "weapon_p250";
      g_PlayerNades[client] = "f";
    }

    if (Chance(0.7)) {
      g_PlayerArmor[client] = 100;
    }
  }
}
