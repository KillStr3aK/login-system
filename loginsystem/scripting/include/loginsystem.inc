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
 * @error             Client is not in game. 
 */ 
native bool LS_IsLoggedIn(int client);

stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}