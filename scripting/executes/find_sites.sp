// ========================================================================
// Thanks to exvel - http://forums.alliedmods.net/showthread.php?p=1287116
// Provided the GetBombsitesIndexes() and tock bool:IsVecBetween
// ========================================================================
stock void GetBombSitesIndexes() {
  int index = -1;

  float vecBombsiteCenterA[3];
  float vecBombsiteCenterB[3];

  index = FindEntityByClassname(index, "cs_player_manager");
  if (IsValidEntity(index)) {
    GetEntPropVector(index, Prop_Send, "m_bombsiteCenterA", vecBombsiteCenterA);
    GetEntPropVector(index, Prop_Send, "m_bombsiteCenterB", vecBombsiteCenterB);
  } else {
    LogError("Failed to find cs_player_manager");
    return;
  }

  index = -1;
  while ((index = FindEntityByClassname(index, "func_bomb_target")) != -1) {
    float vecBombsiteMin[3];
    float vecBombsiteMax[3];

    GetEntPropVector(index, Prop_Send, "m_vecMins", vecBombsiteMin);
    GetEntPropVector(index, Prop_Send, "m_vecMaxs", vecBombsiteMax);

    if (IsVecBetween(vecBombsiteCenterA, vecBombsiteMin, vecBombsiteMax)) {
      g_BombSiteAIndex = index;
    }
    if (IsVecBetween(vecBombsiteCenterB, vecBombsiteMin, vecBombsiteMax)) {
      g_BombSiteBIndex = index;
    }
  }
}

stock bool IsVecBetween(float vecVector[3], float vecMin[3], float vecMax[3]) {
  return ((vecMin[0] <= vecVector[0] <= vecMax[0]) && (vecMin[1] <= vecVector[1] <= vecMax[1]) &&
          (vecMin[2] <= vecVector[2] <= vecMax[2]));
}
