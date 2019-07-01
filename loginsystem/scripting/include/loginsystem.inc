#if defined _loginsystem_included_ 
  #endinput 
#endif 
#define _loginsystem_included_ 
#define PREFIX "\x01[\x0BLogin-System\x01]"
#define empty "\0"

/** 
 * Check if the client is logged in
 * 
 * 
 * @param client        Client Index. 
 * @return             True if the client is logged in, false otherwise. 
 */ 
native bool LS_IsLoggedIn(int client);

/**
 * Called when a player the logged has logged in.
 * @param client client that has logged in.
 */
forward void LS_OnClientLoggedIn(int client);

/**
 * Called when a player the logged has logged out.
 * @param client client that has logged out.
 */
forward void LS_OnClientLoggedOut(int client);

/**
 * Called when a player got banned by an admin.
 * @param client client that has banned.
 */
forward void LS_OnClientGotBanned(int client);

stock bool IsValidClient(int client)
{
	if(client <= 0) 
		return false;
	
	if(client > MaxClients)
		return false;

	if(!IsClientConnected(client))
		return false;

	return IsClientInGame(client);
}