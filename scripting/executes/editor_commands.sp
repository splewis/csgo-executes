public Action Command_EditSpawns(int client, int args) {
  if (g_hEditorEnabled.IntValue == 0) {
    Executes_Message(client, "The editor is currently disabled.");
    return Plugin_Handled;
  }

  BreakBreakableEntities();
  if (!g_EditMode) {
    StartEditMode();
  }

  GiveEditorMenu(client);

  return Plugin_Handled;
}

public Action Command_Name(int client, int args) {
  if (!g_EditMode)
    return Plugin_Handled;

  if (args >= 1 && GetCmdArgString(g_TempNameBuffer, sizeof(g_TempNameBuffer))) {
    if (g_EditingExecutes) {
      GiveNewExecuteMenu(client);
    } else {
      GiveNewSpawnMenu(client);
    }
  } else {
    Executes_Message(client, "Usage: !setname <name>");
  }

  return Plugin_Handled;
}

public Action Command_GotoSpawn(int client, int args) {
  if (g_hEditorEnabled.IntValue == 0) {
    Executes_Message(client, "The editor is currently disabled.");
    return Plugin_Handled;
  }

  if (!g_EditMode) {
    Executes_Message(client, "You are not in edit mode.");
    return Plugin_Handled;
  }

  char buffer[32];
  if (args >= 1 && GetCmdArg(1, buffer, sizeof(buffer))) {
    int spawn = SpawnIdToIndex(buffer);
    if (IsValidSpawn(spawn)) {
      MoveToSpawnInEditor(client, spawn);
    }
  }

  return Plugin_Handled;
}

public Action Command_GotoNearestSpawn(int client, int args) {
  if (g_hEditorEnabled.IntValue == 0) {
    Executes_Message(client, "The editor is currently disabled.");
    return Plugin_Handled;
  }

  if (!g_EditMode) {
    Executes_Message(client, "You are not in edit mode.");
    return Plugin_Handled;
  }

  int spawn = FindClosestSpawn(client);
  if (IsValidSpawn(spawn)) {
    MoveToSpawnInEditor(client, spawn);
  }

  return Plugin_Handled;
}

public Action Command_NextSpawn(int client, int args) {
  if (g_hEditorEnabled.IntValue == 0) {
    Executes_Message(client, "The editor is currently disabled.");
    return Plugin_Handled;
  }

  if (!g_EditMode) {
    Executes_Message(client, "You are not in edit mode.");
    return Plugin_Handled;
  }

  int spawn = g_EditingSpawnIndex + 1;
  while (!IsValidSpawn(spawn) && spawn < MAX_SPAWNS) {
    spawn++;
  }

  if (IsValidSpawn(spawn)) {
    EditSpawn(client, spawn);
  } else {
    g_EditingSpawnIndex = 0;
  }

  return Plugin_Handled;
}
