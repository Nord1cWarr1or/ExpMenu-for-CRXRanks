#include <amxmodx>
#include <amxmisc>
#include <crxranks>

new const PLUGIN_VERSION[] = "1.0.4";

#define AUTO_CONFIG	// Comment out if you don't want the plugin config to be created automatically in "configs/plugins"

new g_iChoosenExp[MAX_PLAYERS + 1];
new g_iMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS], g_iMenuPosition[MAX_PLAYERS + 1];
new bool:g_bAddingExp[MAX_PLAYERS + 1];

#define GetCvarDesc(%0) fmt("%L", LANG_SERVER, %0)

new const g_iNumbersExp[5] =
{
	5,
	10,
	25,
	50,
	100
};

enum _:Cvars
{
	NUM_ON_PAGE,
	FLAG[2],
};

new g_iCvars[Cvars];

public plugin_init()
{
	register_plugin("ExpMenu for CRXRanks", PLUGIN_VERSION, "Nordic Warrior");

	register_menu("Experience menu", 1023, "ExperienceMenu_handler");

	register_clcmd("say /expmenu", "ExperienceMenu");
	register_clcmd("crxranks_expmenu", "ExperienceMenu");

	register_concmd("experience", "UserExp");

	register_dictionary("crx_expmenu.txt");

	arrayset(g_iChoosenExp, g_iNumbersExp[0], sizeof g_iChoosenExp);

	bind_pcvar_num(create_cvar("crxranks_expedit_onpage", "7",
		.description = GetCvarDesc("CRX_EXPEDIT_CVAR_ONPAGE"),
		.has_min = true, .min_val = 1.0,
		.has_max = true, .max_val = 7.0),
		g_iCvars[NUM_ON_PAGE]);

	bind_pcvar_string(create_cvar("crxranks_expedit_flag", "l",
		.description = GetCvarDesc("CRX_EXPEDIT_CVAR_FLAG")),
		g_iCvars[FLAG], charsmax(g_iCvars[FLAG]));

	#if defined AUTO_CONFIG
	AutoExecConfig(true);
	#endif
}

public ExperienceMenu(const iPlayer, iPage)
{
	if(iPage < 0)
		return PLUGIN_HANDLED;

	if(!has_flag(iPlayer, g_iCvars[FLAG]))
	{
		client_print_color(iPlayer, print_team_red, "%l %l", "CRX_EXPEDIT_CHAT_TAG", "CRX_EXPEDIT_CHAT_NO_ACCES");
		return PLUGIN_HANDLED;
	}

	new iPlayers[MAX_PLAYERS], iPlayersNum;
	get_players_ex(iPlayers, iPlayersNum, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);

	new iPlayersCount;

	for(new i; i < iPlayersNum; i++)
		g_iMenuPlayers[iPlayer][iPlayersCount++] = iPlayers[i];

	new i = min(iPage * g_iCvars[NUM_ON_PAGE], iPlayersCount);
	new iStart = i - (i % g_iCvars[NUM_ON_PAGE]);
	new iEnd = min(iStart + g_iCvars[NUM_ON_PAGE], iPlayersCount);
	g_iMenuPosition[iPlayer] = iPage = iStart / g_iCvars[NUM_ON_PAGE];

	new szMenu[MAX_MENU_LENGTH];
	new iMenuItem;
	new iKeys = MENU_KEY_0;
	new iPagesNum = (iPlayersCount / g_iCvars[NUM_ON_PAGE] + ((iPlayersCount % g_iCvars[NUM_ON_PAGE]) ? 1 : 0));

	SetGlobalTransTarget(iPlayer);

	new iLen = formatex(szMenu, charsmax(szMenu), "%l^n%l^n^n", g_bAddingExp[iPlayer] ? "CRX_EXPEDIT_MENU_HEAD_TAKE" : "CRX_EXPEDIT_MENU_HEAD_GIVE", "CRX_EXPEDIT_MENU_HEAD_PAGE", iPage + 1, iPagesNum);

	for(new a = iStart, iTarget; a < iEnd; ++a)
	{
		iTarget = g_iMenuPlayers[iPlayer][a];

		iKeys |= (1<<iMenuItem);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%i. %l^n", ++iMenuItem, "CRX_EXPEDIT_MENU_PLAYERINFO", iTarget, crxranks_get_user_xp(iTarget), crxranks_get_user_level(iTarget));
	}

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y8. \w%l^n", g_bAddingExp[iPlayer] ? "CRX_EXPEDIT_MENU_TAKE" : "CRX_EXPEDIT_MENU_GIVE", g_iChoosenExp[iPlayer]);
	iKeys |= MENU_KEY_8;

	if(iEnd != iPlayersCount)
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y9. \w%l^n\y0. \w%l", "CRX_EXPEDIT_MENU_MORE", iPage ? "CRX_EXPEDIT_MENU_BACK" : "CRX_EXPEDIT_MENU_EXIT");
		iKeys |= MENU_KEY_9;
	}
	else formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y0. \w%l", iPage ? "CRX_EXPEDIT_MENU_BACK" : "CRX_EXPEDIT_MENU_EXIT");

	show_menu(iPlayer, iKeys, szMenu, -1, "Experience menu");
	return PLUGIN_HANDLED;
}

public ExperienceMenu_handler(const iPlayer, iKey)
{
	switch(iKey)
	{
		case 7: ChooseExpMenu(iPlayer);
		case 8: ExperienceMenu(iPlayer, ++g_iMenuPosition[iPlayer]);
		case 9: ExperienceMenu(iPlayer, --g_iMenuPosition[iPlayer]);
		default:
		{
			new iTarget = g_iMenuPlayers[iPlayer][g_iMenuPosition[iPlayer] * g_iCvars[NUM_ON_PAGE] + iKey];

			if(!is_user_connected(iTarget))
			{
				client_print_color(iPlayer, print_team_red, "%l %l", "CRX_EXPEDIT_CHAT_TAG", "CRX_EXPEDIT_CHAT_INVALID_PLAYER");
				ExperienceMenu(iPlayer, g_iMenuPosition[iPlayer]);
				return PLUGIN_HANDLED;
			}

			client_print_color(0, print_team_default, "%l %l", "CRX_EXPEDIT_CHAT_TAG", g_bAddingExp[iPlayer] ? "CRX_EXPEDIT_CHAT_TAKE" : "CRX_EXPEDIT_CHAT_GIVE", iPlayer, g_iChoosenExp[iPlayer], iTarget);
			crxranks_give_user_xp(iTarget, g_bAddingExp[iPlayer] ? -g_iChoosenExp[iPlayer] : g_iChoosenExp[iPlayer]);

			ExperienceMenu(iPlayer, g_iMenuPosition[iPlayer]);
		}
	}
	return PLUGIN_HANDLED;
}

public ChooseExpMenu(const iPlayer)
{
	SetGlobalTransTarget(iPlayer);

	new iMenu = menu_create(fmt("%l", g_bAddingExp[iPlayer] ? "CRX_EXPEDIT_EXPMENU_HEAD_TAKE" : "CRX_EXPEDIT_EXPMENU_HEAD_GIVE", g_iChoosenExp[iPlayer]), "ChooseExpMenu_handler");

	for(new i; i < sizeof g_iNumbersExp; i++)
		menu_additem(iMenu, fmt("%i", g_iNumbersExp[i]));

	menu_additem(iMenu, fmt("^n%l", "CRX_EXPEDIT_EXPMENU_ENTEREXP"));
	menu_additem(iMenu, fmt("%l", g_bAddingExp[iPlayer] ? "CRX_EXPEDIT_EXPMENU_TAKE" : "CRX_EXPEDIT_EXPMENU_GIVE"));

	menu_setprop(iMenu, MPROP_EXITNAME, fmt("%l", "CRX_EXPEDIT_MENU_BACK"));

	menu_display(iPlayer, iMenu);
}

public ChooseExpMenu_handler(const iPlayer, iMenu, iItem)
{
	if(iItem == MENU_EXIT)
	{
		ExperienceMenu(iPlayer, g_iMenuPosition[iPlayer]);
		menu_destroy(iMenu);
		return PLUGIN_HANDLED;
	}

	switch(iItem)
	{
		case 5: client_cmd(iPlayer, "messagemode ^"experience^"");
		case 6: g_bAddingExp[iPlayer] = !g_bAddingExp[iPlayer];
		default: g_iChoosenExp[iPlayer] = g_iNumbersExp[iItem];
	}

	ChooseExpMenu(iPlayer);
	menu_destroy(iMenu);
	return PLUGIN_HANDLED;
}

public UserExp(const iPlayer)
{
	new szExp[8];

	read_args(szExp, sizeof(szExp));
	remove_quotes(szExp);

	new iExp = str_to_num(szExp);

	if(iExp < 1)
	{
		client_print(iPlayer, print_center, "*** %l ***", "CRX_EXPEDIT_CHAT_WRONGNUMBER");

		ChooseExpMenu(iPlayer);
		return PLUGIN_CONTINUE;
	}

	g_iChoosenExp[iPlayer] = iExp;

	ChooseExpMenu(iPlayer);
	return PLUGIN_CONTINUE;
}