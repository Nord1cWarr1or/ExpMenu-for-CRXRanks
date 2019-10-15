#include <amxmodx>
#include <amxmisc>
#include <crxranks>

new const PLUGIN_VERSION[] = "0.3.1";

#define AUTO_CONFIG	// Comment out if you don't want the plugin config to be created automatically in "configs/plugins"

new g_iChoosenExp[MAX_PLAYERS + 1];
new g_iMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS], g_iMenuPosition[MAX_PLAYERS + 1];
new bool:g_bAddingExp[MAX_PLAYERS + 1];

new const g_iNumbersExp[] = 
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
	FLAG[1],
};

new g_iCvars[Cvars];

public plugin_init()
{
	register_plugin("ExpMenu for CRXRanks", PLUGIN_VERSION, "Nordic Warrior");

	register_menu("Experience menu", 1023, "ExperienceMenu_handler");

	register_clcmd("say /expmenu", "ExperienceMenu");
	register_clcmd("crxranks_expmenu", "ExperienceMenu");

	register_concmd("experience", "UserExp");

	arrayset(g_iChoosenExp, g_iNumbersExp[0], charsmax(g_iChoosenExp));

	bind_pcvar_num(create_cvar("crxranks_expedit_onpage", "7", FCVAR_NONE, "Количество игроков на странице в меню", true, 1.0, true, 7.0), g_iCvars[NUM_ON_PAGE]);
	bind_pcvar_string(create_cvar("crxranks_expedit_flag", "l", FCVAR_NONE, "Флаг досупа к меню редактирования"), g_iCvars[FLAG], charsmax(g_iCvars[FLAG]));

	#if defined AUTO_CONFIG
	AutoExecConfig(true);
	#endif
}

public ExperienceMenu(const iPlayer, iPage)
{
	log_amx("%s", g_iCvars[FLAG])
	if(!has_flag(iPlayer, g_iCvars[FLAG]) || iPage < 0)
		return PLUGIN_HANDLED;
	
	new Players[MAX_PLAYERS], iPlayersNum;
	get_players_ex(Players, iPlayersNum, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);

	new iPlayersCount;

	for(new i; i < iPlayersNum; i++)
		g_iMenuPlayers[iPlayer][iPlayersCount++] = Players[i];

	new i = min(iPage * g_iCvars[NUM_ON_PAGE], iPlayersCount);
	new iStart = i - (i % g_iCvars[NUM_ON_PAGE]);
	new iEnd = min(iStart + g_iCvars[NUM_ON_PAGE], iPlayersCount);
	g_iMenuPosition[iPlayer] = iPage = iStart / g_iCvars[NUM_ON_PAGE];

	new szMenu[MAX_MENU_LENGTH];
	new iMenuItem;
	new iKeys = MENU_KEY_0;
	new iPagesNum = (iPlayersCount / g_iCvars[NUM_ON_PAGE] + ((iPlayersCount % g_iCvars[NUM_ON_PAGE]) ? 1 : 0));

	new iLen = formatex(szMenu, charsmax(szMenu), "%s опыт?^nСтраница: \y%i \wиз \y%i^n^n", g_bAddingExp[iPlayer] ? "У кого отнять" : "Кому дать", iPage + 1, iPagesNum);

	for(new a = iStart, iTarget; a < iEnd; ++a)
	{
		iTarget = g_iMenuPlayers[iPlayer][a];

		iKeys |= (1<<iMenuItem);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%i. \w%n (\y%i exp.\w) \w[\r%i LVL\w]^n", ++iMenuItem, iTarget, crxranks_get_user_xp(iTarget), crxranks_get_user_level(iTarget));
	}

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y8. \w%s опыт: \y[\r%i\y]^n", g_bAddingExp[iPlayer] ? "Отнимаемый" : "Выдаваемый", g_iChoosenExp[iPlayer]);
	iKeys |= MENU_KEY_8;

	if(iEnd != iPlayersCount)
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y9. \w%s^n\y0. \w%s", "Далее", iPage ? "Назад" : "Выход");
		iKeys |= MENU_KEY_9;
	}
	else formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y0. \w%s", iPage ? "Назад" : "Выход");

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
			new iTarget = g_iMenuPlayers[iPlayer][g_iMenuPosition[iPlayer] * 8 + iKey];

			client_print_color(0, print_team_default, "^4[CRXRanks] ^3%n ^1%s ^4%i опыта ^3%n", iPlayer, g_bAddingExp[iPlayer] ? "отнял" : "дал", g_iChoosenExp[iPlayer], iTarget);
			crxranks_give_user_xp(iTarget, g_bAddingExp[iPlayer] ? -g_iChoosenExp[iPlayer] : g_iChoosenExp[iPlayer]);

			ExperienceMenu(iPlayer, g_iMenuPosition[iPlayer]);
		}
	}
	return PLUGIN_HANDLED;
}

public ChooseExpMenu(const iPlayer)
{
	new iMenu = menu_create(fmt("\wСколько опыта %s?^nСейчас: \y%i", g_bAddingExp[iPlayer] ? "отнимать" : "выдавать", g_iChoosenExp[iPlayer]), "ChooseExpMenu_handler");

	menu_additem(iMenu, fmt("%i", g_iNumbersExp[0]));
	menu_additem(iMenu, fmt("%i", g_iNumbersExp[1]));
	menu_additem(iMenu, fmt("%i", g_iNumbersExp[2]));
	menu_additem(iMenu, fmt("%i", g_iNumbersExp[3]));
	menu_additem(iMenu, fmt("%i^n", g_iNumbersExp[4]));

	menu_additem(iMenu, "Указать вручную");
	menu_additem(iMenu, fmt("%s \wопыт", g_bAddingExp[iPlayer] ? "\rОтнимать" : "\yВыдавать"));

	menu_setprop(iMenu, MPROP_EXITNAME, "Назад");

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
		case 0: g_iChoosenExp[iPlayer] = g_iNumbersExp[0];
		case 1: g_iChoosenExp[iPlayer] = g_iNumbersExp[1];
		case 2: g_iChoosenExp[iPlayer] = g_iNumbersExp[2];
		case 3: g_iChoosenExp[iPlayer] = g_iNumbersExp[3];
		case 4: g_iChoosenExp[iPlayer] = g_iNumbersExp[4];
		case 5: client_cmd(iPlayer, "messagemode experience");
		case 6: g_bAddingExp[iPlayer] = !g_bAddingExp[iPlayer];
	}
	ChooseExpMenu(iPlayer);
	return PLUGIN_HANDLED;
}

public UserExp(const iPlayer)
{
	new szExp[8];

	read_args(szExp, sizeof(szExp));
	remove_quotes(szExp);

	g_iChoosenExp[iPlayer] = str_to_num(szExp);

	if(g_iChoosenExp[iPlayer] < 1)
	{
		client_print_color(iPlayer, print_team_default, "^4[CRXRanks] ^1Число не может быть ^4меньше 1^1!");

		ChooseExpMenu(iPlayer);
		return PLUGIN_CONTINUE;
	}
	ChooseExpMenu(iPlayer);
	return PLUGIN_CONTINUE;
}