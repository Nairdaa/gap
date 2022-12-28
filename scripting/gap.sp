// #include <sourcemod> /* No need, the compiler adds that on the top of .sp itself */
/* Header files */
#include <cstrike>
#include <sdktools>
#include "colors.sp"

#define POINT_A 0
#define POINT_B 1
#define NUM_POINTS 2
#define CURSOR_TIME GetTickInterval() * 10.0
#define PREVIEW_TIME 1.0
#define RING_START_RADIUS 7.0
#define RING_END_RADIUS 7.7
#define CURSOR_SIZE 3.0

/* Globals */
EngineVersion gEV_Type = Engine_Unknown;

bool gB_ShowCursor[MAXPLAYERS + 1];
bool gB_Gap[MAXPLAYERS + 1];

Handle gH_CursorTimer[MAXPLAYERS + 1];
Handle gH_PreviewTimer[MAXPLAYERS + 1];

int gI_CurrPoint[MAXPLAYERS + 1];
int gI_SnapToGrid[MAXPLAYERS + 1];
int gI_SnapValues[] = {0, 1, 2, 4, 8, 16, 32, 64};
int gI_ModelIndex;
int gI_ColorRed[4] = {255, 0, 0, 255};
int gI_ColorGreen[4] = {0, 255, 0, 255};
int gI_ColorWhite[4] = {255, 255, 255, 255};

float gF_PointPos[MAXPLAYERS + 1][NUM_POINTS][3];
float gF_Gravity;

/* CVARs */
ConVar gCV_BeamMaterial;

/* Plugin information */
public Plugin myinfo =
{
	name = "Gap",
	author = "ici, velocity calculation by Saul and implemented by Charles_(hypnos)",
	description = "",
	version = "1.1",
	url = ""
}

float gF_CursorStart[3][3] =
{
	{CURSOR_SIZE, 0.0, 0.0},
	{0.0, CURSOR_SIZE, 0.0},
	{0.0, 0.0, CURSOR_SIZE}
};

float gF_CursorEnd[3][3] =
{
	{-CURSOR_SIZE, 0.0, 0.0},
	{0.0, -CURSOR_SIZE, 0.0},
	{0.0, 0.0, -CURSOR_SIZE}
};

enum struct Line
{
	float start[3];
	float end[3];
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_gap", CommandGap, "Activates the feature", .flags = 0)

	ConVar sv_gravity = FindConVar("sv_gravity");
	sv_gravity.AddChangeHook(OnGravityChanged);
	gF_Gravity = sv_gravity.FloatValue;

	if ((gEV_Type != Engine_CSS) || (gEV_Type != Engine_CSGO))
	{
		SetFailState("Game not supported.");
	}

	if (gEV_Type == Engine_CSS)
	{
		gCV_BeamMaterial = CreateConVar("gap_beams_material", "sprites/laser.vmt", "Material used for beams. Server restart needed for this to take effect.");
	}
	else
	{
		gCV_BeamMaterial = CreateConVar("gap_beams_material", "sprites/laserbeam.vmt", "Material used for beams. Server restart needed for this to take effect.");
	}
}

public void OnGravityChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gF_Gravity = StringToFloat(newValue);
}

public void OnClientPutInServer(int client)
{
	ResetVariables(client);
}

public void OnMapStart()
{
	char buff[PLATFORM_MAX_PATH];
	gCV_BeamMaterial.GetString(buff, sizeof(buff));
	gI_ModelIndex = PrecacheModel(buff, true);
}

public Action CommandGap(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "You have to be in game to use this command");
		return Plugin_Handled;
	}

	OpenMenu(client);
	return Plugin_Handled;
}

void OpenMenu(int client)
{
	Panel panel = new Panel();

	panel.SetTitle("Gap");
	panel.DrawItem("Select point");

	// Feeling kinda lazy today
	if (gB_ShowCursor[client])
	{
		panel.DrawItem("Show cursor: on");
	}
	else
	{
		panel.DrawItem("Show cursor: off");
	}

	if (gI_SnapToGrid[client] == 0)
	{
		panel.DrawItem("Snap to grid: off");
	}
	else
	{
		char gridText[32];
		FormatEx(gridText, sizeof(gridText), "Snap to grid: %d", gI_SnapValues[ gI_SnapToGrid[client] ] );
		panel.DrawItem(gridText);
	}

	if (gEV_Type == Engine_CSS)
	{
		panel.CurrentKey = 10;
	}
	else
	{
		panel.CurrentKey = 9;
	}
	panel.DrawItem("Exit", ITEMDRAW_CONTROL);

	gB_Gap[client] = panel.Send(client, handler, MENU_TIME_FOREVER);

	if (gB_Gap[client])
	{
		if (gH_CursorTimer[client] != null)
		{
			KillTimer(gH_CursorTimer[client]);
			gH_CursorTimer[client] = null;
		}
		gH_CursorTimer[client] = CreateTimer(CURSOR_TIME, Cursor, GetClientUserId(client), .flags = TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	delete panel;
}

public Action Cursor(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !gB_Gap[client])
	{
		gH_CursorTimer[client] = null;
		return Plugin_Stop;
	}

	if (gI_CurrPoint[client] == POINT_A)
	{
		float endPos[3];

		if (!GetAimPosition(client, endPos))
		{
			return Plugin_Continue;
		}

		DrawCursor(client, endPos, 1.0, CURSOR_TIME, gI_ColorWhite);
	}
	else if (gI_CurrPoint[client] == POINT_B)
	{
		float endPos[3];

		if (!GetAimPosition(client, endPos))
		{
			return Plugin_Continue;
		}

		float startPos[3];
		startPos = gF_PointPos[client][ POINT_A ];

		DrawRing(client, startPos, RING_START_RADIUS, RING_END_RADIUS, CURSOR_TIME, gI_ColorGreen, FBEAM_FADEIN);
		DrawCursor(client, endPos, 1.0, CURSOR_TIME, gI_ColorWhite);
		DrawLine(client, gF_PointPos[ client ][ POINT_A ], endPos, 1.0, CURSOR_TIME, gI_ColorWhite);
	}

	return Plugin_Continue;
}

public int handler(Menu menu, MenuAction action, int client, int item)
{
	if (action != MenuAction_Select)
	{
		gB_Gap[client] = false;

		if (gH_PreviewTimer[client] != null)
		{
			KillTimer(gH_PreviewTimer[client]);
			gH_PreviewTimer[client] = null;
		}

		if (gH_CursorTimer[client] != null)
		{
			KillTimer(gH_CursorTimer[client]);
			gH_CursorTimer[client] = null;
		}

		return 0;
	}

	switch (item)
	{
		case 1: // Select point
		{
			if (GetAimPosition(client, gF_PointPos[ client ][ gI_CurrPoint[client] ]))
			{
				if (gI_CurrPoint[client] == POINT_A && gH_PreviewTimer[client] != null)
				{
					// Don't retrigger the timer
					KillTimer(gH_PreviewTimer[client]);
					gH_PreviewTimer[client] = null;
				}

				gI_CurrPoint[client]++;

				if (gI_CurrPoint[client] == NUM_POINTS)
				{
					float startPos[3], endPos[3];

					startPos = gF_PointPos[client][ POINT_A ];
					endPos   = gF_PointPos[client][ POINT_B ];

					// Draw a line between the two points
					DrawRing(client, startPos, RING_START_RADIUS, RING_END_RADIUS, PREVIEW_TIME, gI_ColorGreen, FBEAM_FADEIN);
					DrawRing(client, endPos, RING_START_RADIUS, RING_END_RADIUS, PREVIEW_TIME, gI_ColorRed, FBEAM_FADEIN);
					DrawLine(client, startPos, endPos, 1.0, PREVIEW_TIME, gI_ColorWhite);
					gH_PreviewTimer[client] = CreateTimer(PREVIEW_TIME, CompleteGap, GetClientUserId(client), .flags = TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

					float distance = GetDistance(startPos, endPos);
					float difference[3];
					SubtractVectors(endPos, startPos, difference);

					if(difference[2] > 65)
					{
						Print2(client, "{CHAT}Distance: {YELLOWORANGE}%.2f {CHAT}DiifX: {YELLOWORANGE}%.2f {CHAT}DiffY: {YELLOWORANGE}%.2f {CHAT}DiffZ: {YELLOWORANGE}%.2f {CHAT}MinVelocity: {YELLOWORANGE}Impossible Jump ΔZ>65",
							distance,
							difference[0], difference[1], difference[2]);
					}
					else
					{
						// Credit to Saul for velocity calculations
						float gFallTime, gFallHeight, gFallVelocity;

						if (difference[2] > 64)
						{
							gFallHeight = 65 - difference[2]; // z distance from top of jump to selected point, assuming sv_gravity 800 is used.
						}
						else
						{
							gFallHeight = 64 - difference[2];
						}

						float m_flGravity = GetEntityGravity(client);

						float g_flGravityTick = SquareRoot(2 * 800 * 57.0) - (gF_Gravity  * m_flGravity * 1.5 * GetTickInterval());
						gFallVelocity = -1 * SquareRoot(2 * gF_Gravity * m_flGravity * gFallHeight); // z velocity player should have right before hitting the ground
						gFallTime = -1 * (gFallVelocity - g_flGravityTick) / gF_Gravity * m_flGravity; // The amount of time the jump should have taken

						float gInitialVel[3];

						gInitialVel[0] = (endPos[0] - startPos[0]) / gFallTime; // Minimum velocity needed in x and y directions
						gInitialVel[1] = (endPos[1] - startPos[1]) / gFallTime; // to reach the destination

						float gMinVel = SquareRoot(Pow(gInitialVel[0], 2.0) + Pow(gInitialVel[1], 2.0));
						float gInitialTick = Pow((gMinVel - 16.97) / 30.02, 1 / 0.5029);
						float gFallTimeTicks = gFallTime * (1/GetTickInterval()); // carnifex' fault if it bugs
						float gVelGain = (30.02 * Pow(gInitialTick + gFallTimeTicks, 0.5029) + 16.97) - (30.02 * Pow(gInitialTick, 0.5029) + 16.97);
						float gMinVelOneTick = gMinVel - gVelGain;

						if(gMinVelOneTick < 0 || gMinVel < 16.97)
						{
							gMinVelOneTick = 0.0;
						}


						// Credit to Charles_(hypnos) for the implementation of velocity stuff (https://hyps.dev/)
						Print2(client, "{CHAT}Distance: {YELLOWORANGE}%.2f {CHAT}DiifX: {YELLOWORANGE}%.2f {CHAT}DiffY: {YELLOWORANGE}%.2f {CHAT}DiffZ: {YELLOWORANGE}%.2f {CHAT}MinVelocity: {YELLOWORANGE}%.2f {CHAT}MinVelocityWith1Tick: {YELLOWORANGE}%.2f",
							distance,
							difference[0], difference[1], difference[2], gMinVel, gMinVelOneTick);
					}

					gI_CurrPoint[client] = POINT_A;
				}
			}
			else
			{
				Print2(client, "{CHAT}Couldn't get point position (raytrace did not hit). Try again.");
			}
			OpenMenu(client);
		}
		case 2: // Show cursor
		{
			gB_ShowCursor[client] = !gB_ShowCursor[client];
			OpenMenu(client);
		}
		case 3: // Snap to grid
		{
			gI_SnapToGrid[client]++;
			gI_SnapToGrid[client] = gI_SnapToGrid[client] % sizeof(gI_SnapValues);

			OpenMenu(client);
		}
		case 9, 10:
		{
			gB_Gap[client] = false;

			if (gH_PreviewTimer[client] != null)
			{
				KillTimer(gH_PreviewTimer[client]);
				gH_PreviewTimer[client] = null;
			}

			if (gH_CursorTimer[client] != null)
			{
				KillTimer(gH_CursorTimer[client]);
				gH_CursorTimer[client] = null;
			}
		}

	}
	return 0;
}

public Action CompleteGap(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !gB_Gap[client])
	{
		gH_PreviewTimer[client] = null;
		return Plugin_Stop;
	}

	float startPos[3], endPos[3];

	startPos = gF_PointPos[client][ POINT_A ];
	endPos   = gF_PointPos[client][ POINT_B ];

	DrawRing(client, startPos, RING_START_RADIUS, RING_END_RADIUS, PREVIEW_TIME, gI_ColorGreen, FBEAM_FADEIN);
	DrawRing(client, endPos, RING_START_RADIUS, RING_END_RADIUS, PREVIEW_TIME, gI_ColorRed, FBEAM_FADEIN);
	DrawLine(client, startPos, endPos, 1.0, PREVIEW_TIME, gI_ColorWhite);

	return Plugin_Continue;
}

bool GetAimPosition(int client, float endPosition[3])
{
	float eyePosition[3];
	GetClientEyePosition(client, eyePosition);

	float eyeAngles[3];
	GetClientEyeAngles(client, eyeAngles);

	//float dirVector[3];
	//GetAngleVectors(eyeAngles, dirVector, NULL_VECTOR, NULL_VECTOR);

	TR_TraceRayFilter(eyePosition, eyeAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter);

	if (TR_DidHit(null))
	{
		TR_GetEndPosition(endPosition, null);

		if (gI_SnapToGrid[client])
		{
			endPosition = SnapToGrid(endPosition, gI_SnapValues[ gI_SnapToGrid[client] ], true);
		}
		return true;
	}
	return false;
}

public bool TraceFilter(int entity, int contentsMask)
{
	// Pass through players
	return !(0 < entity && entity <= MaxClients);
}

stock void DrawLine(int client, float start[3], float end[3], float width, float life, int color[4])
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	TE_SetupBeamPoints(start, end,
		.ModelIndex = gI_ModelIndex,
		.HaloIndex = 0,
		.StartFrame = 0,
		.FrameRate = 0,
		.Life = life,
		.Width = width,
		.EndWidth = width,
		.FadeLength = 0,
		.Amplitude = 0.0,
		.Color = color,
		.Speed = 0);

	TE_SendToAllInRange(origin, RangeType_Visibility, .delay = 0.0);
}

stock void DrawRing(int client, float center[3], float startRadius, float endRadius, float life, int color[4], int flags = 0)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	TE_SetupBeamRingPoint(center,
		.Start_Radius = startRadius,
		.End_Radius = endRadius,
		.ModelIndex = gI_ModelIndex,
		.HaloIndex = 0,
		.StartFrame = 0,
		.FrameRate = 30,
		.Life = life,
		.Width = 2.0,
		.Amplitude = 0.0,
		.Color = color,
		.Speed = 3,
		.Flags = flags);

	TE_SendToAllInRange(origin, RangeType_Visibility, .delay = 0.0);
}

stock void DrawCursor(int client, float center[3], float width, float life, int color[4])
{
	if (!gB_ShowCursor[client])
	{
		return;
	}

	Line line[3];

	for (int i = 0; i < 3; i++)
	{
		line[ i ].start = gF_CursorStart[ i ];
		line[ i ].end = gF_CursorEnd[ i ];

		//RotateClockwise(line[ i ].start, 45.0);
		//RotateClockwise(line[ i ].end, 45.0);

		AddVectors(center, line[ i ].start, line[ i ].start);
		AddVectors(center, line[ i ].end, line[ i ].end);

		DrawLine(client, line[ i ].start, line[ i ].end, width, life, color);
	}
}

void ResetVariables(int client)
{
	gB_Gap[client] = false;
	gI_CurrPoint[client] = POINT_A;

	for (int i = 0; i < NUM_POINTS; i++)
	{
		gF_PointPos[client][i] = NULL_VECTOR;
	}

	gI_SnapToGrid[client] = 0; // off
	gB_ShowCursor[client] = true;

	if (gH_PreviewTimer[client] != null)
	{
		KillTimer(gH_PreviewTimer[client]);
		gH_PreviewTimer[client] = null;
	}

	if (gH_CursorTimer[client] != null)
	{
		KillTimer(gH_CursorTimer[client]);
		gH_CursorTimer[client] = null;
	}
}

float GetDistance(float startPos[3], float endPos[3])
{
	float difference[3];
	SubtractVectors(endPos, startPos, difference);
	return GetVectorLength(difference);
}

stock float[] SnapToGrid(float pos[3], int grid, bool third)
{
	float origin[3];
	origin = pos;

	origin[0] = float(RoundToNearest(pos[0] / grid) * grid);
	origin[1] = float(RoundToNearest(pos[1] / grid) * grid);

	if(third)
	{
		origin[2] = float(RoundToNearest(pos[2] / grid) * grid);
	}

	return origin;
}

stock void RotateClockwise(float p[3], float angle) // 2d
{
	float s = Sine( DegToRad(angle) );
	float c = Cosine( DegToRad(angle) );

	p[0] = p[0] * c + p[1] * s;
	p[1] = p[1] * c - p[0] * s;
}
