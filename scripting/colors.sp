#if defined _gap_colors_included
 #endinput
#endif
#define _gap_colors_included

#include <regex>

#define CHAT_PREFIX "{ALTO}[{PERIWINKLE}Gap{ALTO}]"

static stock StringMap colors;
static stock EngineVersion game;

stock void InitColors()
{
	if (colors != null)
		return;
	
	colors = new StringMap();
	game = GetEngineVersion();

	// Reddish
	colors.SetValue("CARNATION", game != Engine_CSGO ? 0xF25A5A : 0x07)
	colors.SetValue("MAUVELOUS", game != Engine_CSGO ? 0xF29191 : 0x07)

	// Pinkish
	colors.SetValue("SUNGLO", game != Engine_CSGO ? 0xE26A7E : 0x03)
	colors.SetValue("BRICKRED", game != Engine_CSGO ? 0xCB344B : 0x03)
	colors.SetValue("YOURPINK", game != Engine_CSGO ? 0xFFCCCC : 0x03)
	colors.SetValue("HOTPINK", game != Engine_CSGO ? 0xFF69B4 : 0x03)

	// Orangish
	colors.SetValue("PUMPKIN", game != Engine_CSGO ? 0xFF711A : 0x10)
	colors.SetValue("CORAL", game != Engine_CSGO ? 0xFF914D : 0x10)
	colors.SetValue("SUNSETORANGE", game != Engine_CSGO ? 0xFF4D4D : 0x10)
	colors.SetValue("YELLOWORANGE", game != Engine_CSGO ? 0xFFA64D : 0x10)

	// Yellowish
	colors.SetValue("TURBO", game != Engine_CSGO ? 0xFAF200 : 0x09)
	colors.SetValue("LASERLEMON", game != Engine_CSGO ? 0xFFFA66 : 0x09)
	colors.SetValue("GOLD", game != Engine_CSGO ? 0xFFD700 : 0x09)

	// Greenish
	colors.SetValue("SUSHI", game != Engine_CSGO ? 0xA3BD42 : 0x06)
	colors.SetValue("WATTLE", game != Engine_CSGO ? 0xD2DD49 : 0x06)

	// Blueish
	colors.SetValue("DODGERBLUE", game != Engine_CSGO ? 0x4D91FF : 0x0B)
	colors.SetValue("PERIWINKLE", game != Engine_CSGO ? 0xB3D0FF : 0x0A)
	colors.SetValue("CYAN", game != Engine_CSGO ? 0x00FFFF : 0x0B)

	// Misc
	colors.SetValue("WHITE", game != Engine_CSGO ? 0xFFFFFF : 0x01)
	colors.SetValue("RED", game != Engine_CSGO ? 0xFF0000 : 0x02)
	colors.SetValue("BLUE", game != Engine_CSGO ? 0x3D87FF : 0x0C)
	colors.SetValue("GREEN", game != Engine_CSGO ? 0x00FF08 : 0x04)
	colors.SetValue("YELLOW", game != Engine_CSGO ? 0xFFFF00 : 0x09)
	colors.SetValue("AQUAMARINE", game != Engine_CSGO ? 0x63F8F3 : 0x0B)
	colors.SetValue("MERCURY", game != Engine_CSGO ? 0xE6E6E6 : 0x08)
	colors.SetValue("TUNDORA", game != Engine_CSGO ? 0x404040 : 0x08)
	colors.SetValue("ALTO", game != Engine_CSGO ? 0xE0E0E0 : 0x0B)

	// Defaults
	colors.SetValue("CHAT", game != Engine_CSGO ? 0xFFFFFF : 0x01)
	colors.SetValue("ADMIN", game != Engine_CSGO ? 0x99FF99 : 0x0B)
	colors.SetValue("TARGET", game != Engine_CSGO ? 0x00FF08 : 0x04)
}

stock void Print2(int client, const char[] message, any ...)
{
	InitColors();
	
	char buffer[1024], buffer2[1024];
	
	FormatEx(buffer, sizeof(buffer), "\x01%s %s", CHAT_PREFIX, message);
	VFormat(buffer2, sizeof(buffer2), buffer, 3);
	ReplaceColorCodes(buffer2, sizeof(buffer2));

	if (game != Engine_CSGO)
	{
		Handle msg = StartMessageOne("SayText2", client);
		if (msg == null) return;
		BfWriteByte(msg, 0); // author
		BfWriteByte(msg, true); // chat
		BfWriteString(msg, buffer2); // translation
		EndMessage();
	}
	else
	{
		PrintToChat(client, buffer2);
	}
}

stock void Print2All(const char[] message, any ...)
{
	InitColors();
	
	char buffer[1024], buffer2[1024];
	
	FormatEx(buffer, sizeof(buffer), "\x01%s %s", CHAT_PREFIX, message);
	VFormat(buffer2, sizeof(buffer2), buffer, 2);
	ReplaceColorCodes(buffer2, sizeof(buffer2));
	
	if (game != Engine_CSGO)
	{
		Handle msg = StartMessageAll("SayText2");
		if (msg == null) return;
		BfWriteByte(msg, 0); // author
		BfWriteByte(msg, true); // chat
		BfWriteString(msg, buffer2); // translation
		EndMessage();
	}
	else
	{
		PrintToChatAll(buffer2);
	}
}

stock void ReplaceColorCodes(char[] input, int maxlen)
{
	int cursor;
	int value;
	char tag[32], buff[32];
	char[] output = new char[maxlen];
	strcopy(output, maxlen, input);
	
	Regex regex = new Regex("{[a-zA-Z0-9]+}");
	for (int i = 0; i < 1000; i++)
	{
		if (regex.Match(input[cursor]) < 1)
		{
			delete regex;
			strcopy(input, maxlen, output);
			return;
		}

		// Found a potential tag string
		GetRegexSubString(regex, 0, tag, sizeof(tag));
		
		// Update the cursor
		cursor = StrContains(input[cursor], tag) + cursor + 1;
		
		// Get rid of brackets
		strcopy(buff, sizeof(buff), tag);
		ReplaceString(buff, sizeof(buff), "{", "");
		ReplaceString(buff, sizeof(buff), "}", "");
		
		// Does such a color exist?
		if (!colors.GetValue(buff, value))
			continue; // No, keep iterating through the string
		
		// Yes, it does. Replace text with the corresponding color
		if (game != Engine_CSGO)
			Format(buff, sizeof(buff), "\x07%06X", value);
		else
			Format(buff, sizeof(buff), "%c", value);
		
		ReplaceString(output, maxlen, tag, buff);
	}
}