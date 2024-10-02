#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>
// #include <xs>

#define PLUGIN "Mario Coin"
#define VERSION "1.0"
#define AUTHOR "RedSMURF"

#define ENABLED "\yENABLED"
#define DISABLED "\rDISABLED"

#pragma semicolon 1
#define MAX_PLAYERS 32

#define HUD_FREQ 1.0
#define COIN_FREQ 5.0


#define is_player(%1) (0 < %1 < g_maxPlayers)

enum _:iCoinSequences {
    CoinIdle = 0,
    CoinFloat,
    CoinSpin
}

enum _:iTaskIds ( += 128637) { // TASKID On Do
    TASKID_HUD_REFRESH,
    TASKID_PLAYER_RESPAWN,
    TASKID_COIN_FADE,
    TASKID_COIN_ACTIVATE
}

enum _:iCvars {
    CVAR_COINENABLE,
    CVAR_COINMAX,
    CVAR_COINPERBODY,
    CVAR_COINGLOW,
    CVAR_COINLIGHT,
    CVAR_COINFADE,
    //CVAR_COINPHYSICS,
    //CVAR_COINSHOOT,
    CVAR_RESPAWNTIME
}

new g_iCoinCount[ MAX_PLAYERS + 1 ];
new g_iUpCount[ MAX_PLAYERS + 1 ];
new bool:g_bPickUp[ MAX_PLAYERS + 1 ];
new g_iCoinVault;
new g_iUpVault;

new g_Cvars[iCvars];
new g_coinClassName[] = "MarioCoin";
new g_maxPlayers;

new g_modelMarioCoin[] = "models/MarioCoins/mario_coin.mdl";
new g_soundCoinGained[] = "MarioCoins/coingained.wav";
new g_soundLifeGained[] = "MarioCoins/lifegained.wav";
new g_soundRespawned[] = "MarioCoins/respawned.wav";

// new HamHook:g_coinDamageHandler;
// new HamHook:g_coinShootHandler;

new syncHudObj;
new syncHudObj2;

//new g_iForward = 0;
//new Float:g_fMultiplier = 22.0;

public plugin_init(){

    register_plugin( PLUGIN, VERSION, AUTHOR );

    g_Cvars[ CVAR_COINENABLE ] = register_cvar( "mc_coin_enable", "1" ); // 0 1
    g_Cvars[ CVAR_COINMAX ] = register_cvar( "mc_coin_max", "5" ); // ?
    g_Cvars[ CVAR_COINPERBODY ] = register_cvar( "mc_coin_perbody", "1" ); // ?
    g_Cvars[ CVAR_COINGLOW ] = register_cvar( "mc_coin_glow", "1" ); // 0 1
    g_Cvars[ CVAR_COINLIGHT ] = register_cvar( "mc_coin_light", "0" ); // 0 1
    g_Cvars[ CVAR_COINFADE ] = register_cvar( "mc_coin_fade", "-1" ); // -1 ? 
    //g_Cvars[ CVAR_COINPHYSICS ] = register_cvar( "mc_coin_physics", "1" ); // 0 1 
    //g_Cvars[ CVAR_COINSHOOT ] = register_cvar( "mc_coin_shoot", "1" ); // 0 1
    g_Cvars[ CVAR_RESPAWNTIME ] = register_cvar( "mc_respawntime", "10" ); // ?

    g_iCoinVault = nvault_open( "MC Coin Vault" );
    g_iUpVault = nvault_open( "MC Up Vault" );

    register_think( g_coinClassName, "coinThink" );
    register_touch( g_coinClassName, "player", "coinTouch" );

    register_clcmd( "mc_coin_set", "setCoin", ADMIN_LEVEL_A );
    register_clcmd( "mc_coins_set", "setCoin", ADMIN_LEVEL_A );
    register_clcmd( "mc_up_set", "setUp", ADMIN_LEVEL_A );

    register_clcmd( "drop", "coinDrop" );

    // register_concmd( "mc_coin_physics", "cpShowMenu", ADMIN_LEVEL_A );
    // register_clcmd( "say /coinphysics", "cpShowMenu", ADMIN_LEVEL_A );

    register_logevent( "Event_RoundStart", 2, "1=Round_Start" );
    register_logevent( "Event_RoundEnd", 2, "1=Round_End" );
    register_event( "DeathMsg", "Event_DeathMsg", "a" );

    syncHudObj = CreateHudSyncObj(); // Coin Hud
    syncHudObj2 = CreateHudSyncObj(); // Player Respawn

    g_maxPlayers = get_maxplayers();
    // updateHooks();

    if ( get_pcvar_num( g_Cvars[CVAR_COINENABLE]) ){
        set_task( HUD_FREQ, "showHud", TASKID_HUD_REFRESH, _, _, "b" );
    }

}


public plugin_precache(){

    //g_coinDamageHandler = RegisterHam( Ham_TakeDamage, g_coinClassName, "coinDamage" );
    //g_coinShootHandler = RegisterHam( Ham_TraceAttack, g_coinClassName, "coinShoot" );

    precache_model( g_modelMarioCoin );

    precache_sound( g_soundCoinGained );
    precache_sound( g_soundLifeGained );
    precache_sound( g_soundRespawned );

}

// public cpShowMenu( id ){

//     new iMenu = menu_create( "\yCoin Physics", "cpMenuHandler" );
//     new szTemp[32];

//     formatex( szTemp, charsmax( szTemp ), "\wCoin Physics %s", get_pcvar_num( g_Cvars[CVAR_COINPHYSICS] ) ? ENABLED : DISABLED );
//     menu_additem( iMenu, szTemp );

//     formatex( szTemp, charsmax( szTemp ), "\wCoin Shoot %s", get_pcvar_num( g_Cvars[CVAR_COINSHOOT] ) ? ENABLED : DISABLED );
//     menu_additem( iMenu, szTemp );

//     menu_setprop( iMenu, MPROP_EXIT, MEXIT_ALL );
//     menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );

//     menu_display( id, iMenu );

// }

// public cpMenuHandler( id, menu, item ){

//     if ( item == MENU_EXIT ){
//         menu_destroy( menu );
//         return PLUGIN_HANDLED;
//     }

//     switch( item ){
        
//         case 0 : {
//             set_pcvar_num( g_Cvars[CVAR_COINPHYSICS], !get_pcvar_num( g_Cvars[CVAR_COINPHYSICS] ));
//             updateHooks();
//         }
//         case 1 : {
//             set_pcvar_num( g_Cvars[CVAR_COINSHOOT], !get_pcvar_num( g_Cvars[CVAR_COINSHOOT] ));
//             updateHooks();
//         }
//     }

//     menu_destroy( menu );
//     cpShowMenu( id );
//     return PLUGIN_HANDLED; 

// }

// public updateHooks(){

//     if ( get_pcvar_num( g_Cvars[CVAR_COINPHYSICS] )){

//         EnableHamForward( g_coinDamageHandler );
//         EnableHamForward( g_coinShootHandler );

//     }else {

//         DisableHamForward( g_coinDamageHandler );
//         DisableHamForward( g_coinShootHandler );
//     }

//     if ( get_pcvar_num( g_Cvars[CVAR_COINPHYSICS] ) && get_pcvar_num( g_Cvars[CVAR_COINSHOOT] ) && !g_iForward ){

//         g_iForward = register_forward( FM_TraceLine, "fwTraceLine" );

//     }

//     if ( (!get_pcvar_num( g_Cvars[CVAR_COINPHYSICS] ) || !get_pcvar_num( g_Cvars[CVAR_COINSHOOT] )) && g_iForward ){

//         unregister_forward( FM_TraceLine, g_iForward );
//         g_iForward = 0;

//     }

// }

// public coinDamage( iCoin, iInflictor, iAttacker, Float:fDamage, iDamageBits ){

//     static szTemp[ 32 ];
//     entity_get_string( iCoin, EV_SZ_classname, szTemp, charsmax( szTemp ) );

//     if ( !equal( g_coinClassName, szTemp )) return HAM_IGNORED;

//     if ( !is_valid_ent( iCoin ) ) return HAM_IGNORED;

//     static Float:fCoinVelocity[ 3 ], Float:fCoinOrigin[ 3 ], Float:fInflictorOrigin[ 3 ];
    
//     entity_get_vector( iCoin, EV_VEC_velocity, fCoinVelocity );
//     entity_get_vector( iCoin, EV_VEC_origin, fCoinOrigin );
//     entity_get_vector( iInflictor, EV_VEC_origin, fInflictorOrigin );

//     static Float:fTemp[ 3 ];
//     xs_vec_sub( fCoinOrigin, fInflictorOrigin, fTemp );
//     xs_vec_normalize( fTemp, fTemp );
//     xs_vec_mul_scalar( fTemp, fDamage, fTemp );
//     xs_vec_mul_scalar( fTemp, g_fMultiplier, fTemp );

//     xs_vec_add( fTemp, fCoinVelocity, fCoinVelocity );
//     entity_set_vector( iCoin, EV_VEC_velocity, fCoinVelocity );

//     SetHamParamFloat( 4, 0.0 );
//     return HAM_IGNORED;

// }

// public coinShoot( iCoin, iAttacker, Float:fDamage, Float:fDirection[ 3 ], iTraceHandler, iDamageBits ){

//     static szTemp[ 32 ];
//     entity_get_string( iCoin, EV_SZ_classname, szTemp, charsmax( szTemp ) );

//     if ( !equal( g_coinClassName, szTemp )) return HAM_IGNORED;

//     if ( !is_valid_ent( iCoin ) ) return HAM_IGNORED;

//     new Float:fCoinVelocity[ 3 ];
//     entity_get_vector( iCoin, EV_VEC_velocity, fCoinVelocity );

//     xs_vec_mul_scalar( fDirection, fDamage, fDirection );
//     xs_vec_mul_scalar( fDirection, g_fMultiplier, fDirection );

//     xs_vec_add( fDirection, fCoinVelocity, fCoinVelocity );
//     entity_set_vector( iCoin, EV_VEC_velocity, fCoinVelocity );

//     return HAM_IGNORED;

// }

// public fwTraceLine( Float:fStart[ 3 ], Float:fEnd[ 3 ], iCond, id, iTraceHandler ){

//     if ( !is_user_connected( id ) || !is_user_alive( id ) ) return FMRES_IGNORED;

//     if ( is_player( get_tr2( iTraceHandler, TR_pHit ) )) return FMRES_IGNORED;

//     static Float:fVecEndPos[ 3 ], szTemp[32], iNewTraceHandler, iCoin = 0;
//     get_tr2( iTraceHandler, TR_vecEndPos );

//     while(( iCoin = find_ent_in_sphere( iCoin, fVecEndPos, 100.0 ) )){

//         engfunc( EngFunc_TraceModel, fStart, fEnd, HULL_POINT, iCoin, iNewTraceHandler );
//         entity_get_string( iCoin, EV_SZ_classname, szTemp, charsmax( szTemp ) );

//         if ( is_valid_ent( get_tr2( iNewTraceHandler, TR_pHit )) && equal( g_coinClassName, szTemp )){

//             get_tr2( iNewTraceHandler, TR_vecEndPos, fVecEndPos );
//             set_tr2( iTraceHandler, TR_vecEndPos, fVecEndPos );

//             set_tr2( iTraceHandler, TR_pHit, iCoin );

//         }

//     }

//     return FMRES_IGNORED;
// }

public setCoin( id ){

    new szPlayer[32], szCoin[3];
    
    read_argv( 1, szPlayer, charsmax( szPlayer ) );
    read_argv( 2, szCoin, 2 );

    new iCoinMax = get_pcvar_num( g_Cvars[CVAR_COINMAX] );
    new iPlayer = get_user_index( szPlayer );
    new iCoin = str_to_num( szCoin );

    g_iCoinCount[ iPlayer ] = iCoin % iCoinMax;
    g_iUpCount[ iPlayer ] = iCoin / iCoinMax;

    emit_sound( id , CHAN_ITEM, g_soundCoinGained, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );

}

public setUp( id ){

    new szPlayer[32], szUp[3];
    
    read_argv( 1, szPlayer, charsmax( szPlayer ) );
    read_argv( 2, szUp, 2 );

    new iPlayer = get_user_index( szPlayer );
    new iUp = str_to_num( szUp );

    g_iUpCount[ iPlayer ] = iUp;

    emit_sound( iPlayer , CHAN_ITEM, g_soundLifeGained, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );

}

public Event_RoundStart(){
    remove_entity_name( g_coinClassName );
}

public Event_RoundEnd(){

    new iPlayers[32], num, i;
    get_players( iPlayers, num, "ch" );

    for ( i = 0; i < num; i ++ ){

        new iPlayer = iPlayers[i];
        if ( task_exists( iPlayer + TASKID_PLAYER_RESPAWN ) ){
            ClearSyncHud( iPlayer, syncHudObj2 );
            g_iUpCount[ iPlayer ] ++;
            remove_task( iPlayer + TASKID_PLAYER_RESPAWN );
        }
    }

}

public Event_DeathMsg(){

    if ( !get_pcvar_num( g_Cvars[CVAR_COINENABLE]) ) return PLUGIN_HANDLED;

    new iVictim = read_data( 2 );

    if ( g_iUpCount[ iVictim ] > 0 && !is_user_bot( iVictim ) ){

        new iRespawntime = get_pcvar_num( g_Cvars[CVAR_RESPAWNTIME] );

        set_hudmessage( 255, 255, 0, -1.0, 0.25, 0, 0.0, 5.0 );
        ShowSyncHudMsg( iVictim, syncHudObj2, "You will be respawned in %d second%s", iRespawntime,
        iRespawntime == 1 ? "" : "s" );

        g_iUpCount[ iVictim ] --;

        set_task( float( iRespawntime ), "playerRespawn", iVictim + TASKID_PLAYER_RESPAWN );

    }

    new Float:fOrigin[3], Float:fVelocity[ 3 ];
    entity_get_vector( iVictim, EV_VEC_origin, fOrigin );
    velocity_by_aim( iVictim, 0, fVelocity );

    coinCreate( fOrigin, fVelocity, MOVETYPE_NONE );

    return PLUGIN_HANDLED;

}

public coinCreate( Float:coinOrigin[ 3 ], Float:coinVelocity[ 3 ], iMoveType ){

    new eCoin = create_entity( "info_target" );

    coinVelocity[ 2 ] += 100;
    // coinOrigin[ 2 ] += 50;

    entity_set_string( eCoin, EV_SZ_classname, g_coinClassName );
    entity_set_vector( eCoin, EV_VEC_velocity, coinVelocity );
    entity_set_vector( eCoin, EV_VEC_origin, coinOrigin );
    entity_set_model( eCoin, g_modelMarioCoin );

    entity_set_int( eCoin, EV_INT_solid, SOLID_TRIGGER );
    entity_set_int( eCoin, EV_INT_movetype, iMoveType );
    entity_set_float( eCoin, EV_FL_framerate, 1.0 );
    entity_set_int( eCoin, EV_INT_sequence, CoinFloat );

    // engfunc( EngFunc_DropToFloor, eCoin );

    engfunc( EngFunc_SetSize, eCoin, Float:{ -5.0, -5.0, -5.0 }, Float:{ 5.0, 5.0, 5.0 } );

    if ( get_pcvar_num( g_Cvars[CVAR_COINGLOW] ) != 0 ){
        set_rendering( eCoin, kRenderFxGlowShell, 255, 255, 0, kRenderNormal, 25 );
    }

    if ( get_pcvar_num( g_Cvars[CVAR_COINLIGHT] ) != 0 ){
        entity_set_float( eCoin, EV_FL_nextthink, get_gametime() + 1.0 );
    }

    if ( get_pcvar_num( g_Cvars[CVAR_COINFADE] ) >= 0 ){
        set_task( float( get_pcvar_num( g_Cvars[CVAR_COINFADE]) ), "coinFade", eCoin );
    }

    return eCoin;

}


public coinDrop( iPlayer ){

    if ( !is_user_connected( iPlayer ) || !is_user_alive( iPlayer ) ) return PLUGIN_CONTINUE;

    new iWpn = get_user_weapon( iPlayer, _, _ );

    if ( g_iCoinCount[ iPlayer ] == 0 || iWpn != CSW_KNIFE ) return PLUGIN_CONTINUE;

    g_iCoinCount[ iPlayer ]--;

    if ( task_exists( iPlayer + TASKID_COIN_ACTIVATE ) == 1 )
        remove_task( iPlayer + TASKID_COIN_ACTIVATE );

    g_bPickUp[ iPlayer ] = false;
    set_task( 0.25, "coinActivate", iPlayer + TASKID_COIN_ACTIVATE );

    new Float:fOrigin[3], Float:fVelocity[3];
    entity_get_vector( iPlayer, EV_VEC_origin, fOrigin );
    velocity_by_aim( iPlayer, 375, fVelocity );

    coinCreate( fOrigin, fVelocity, MOVETYPE_TOSS );

    return PLUGIN_CONTINUE;

}

public coinActivate( iTaskId ){

    new iPlayer = iTaskId - TASKID_COIN_ACTIVATE;
    g_bPickUp[ iPlayer ] = true;

}

public coinFade( eCoin ){

    if ( is_valid_ent(eCoin) )
         remove_entity( eCoin );

}

public coinThink( eCoin ){

    if ( !is_valid_ent(eCoin) ) return;

    new Float:fOrigin[3];
    entity_get_vector( eCoin, EV_VEC_origin, fOrigin );

    dynamicLight( fOrigin, 255, 255, 0, 25 );

    entity_set_float( eCoin, EV_FL_nextthink, get_gametime() + COIN_FREQ );

}

stock dynamicLight( Float:fOrigin[ 3 ], r, g, b, a ){

    engfunc( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fOrigin );

    write_byte( TE_DLIGHT );
    write_coord_f( fOrigin[ 0 ]);
    write_coord_f( fOrigin[ 1 ]);
    write_coord_f( fOrigin[ 2 ]); 
    write_byte( 15 );
    write_byte( r );
    write_byte( g );
    write_byte( b );
    write_byte( a );
    write_byte( 5 );

    message_end();

}

public coinTouch( eCoin, iPlayer ){

    if ( !is_valid_ent( eCoin ) ) 
        return PLUGIN_HANDLED;

    if ( !is_user_connected( iPlayer ) || !is_user_alive( iPlayer ) || is_user_bot ( iPlayer ) ) 
        return PLUGIN_HANDLED;

    if ( g_bPickUp[ iPlayer ] == false ) return PLUGIN_HANDLED;

    new iCoinPerBody = get_pcvar_num( g_Cvars[CVAR_COINPERBODY] );
    new iCoinMax = get_pcvar_num( g_Cvars[CVAR_COINMAX] );

    g_iCoinCount[ iPlayer ] += iCoinPerBody;

    if ( g_iCoinCount[ iPlayer ] >= iCoinMax ){

        g_iCoinCount[ iPlayer ] -= iCoinMax;
        g_iUpCount[ iPlayer ] ++; 

        set_hudmessage( 255, 255, 0, -1.0, 0.25, 0, 0.0, 5.0 );
        ShowSyncHudMsg( iPlayer, syncHudObj2, "You Got 1UP, Let's Fucking Go !" );

        emit_sound( iPlayer, CHAN_ITEM, g_soundLifeGained, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );

    }else {

        set_hudmessage( 255, 255, 0, -1.0, 0.25, 0, 0.0, 5.0 );
        ShowSyncHudMsg( iPlayer, syncHudObj2, "You Got 1 Coin" );

        emit_sound( iPlayer, CHAN_ITEM, g_soundCoinGained, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );

    }

    entity_set_int( eCoin, EV_INT_flags, FL_KILLME );

    return PLUGIN_CONTINUE;

}

public showHud(){

    new iPlayers[32], num, i;
    new iCoinMax = get_pcvar_num( g_Cvars[CVAR_COINMAX] );

    get_players( iPlayers, num, "ch" );

    for ( i = 0; i < num; i ++ ){

        new iPlayer = iPlayers[i];

        set_hudmessage( 255, 255, 0, 0.0125, 0.20, 0, 0.0, HUD_FREQ );

        if ( g_iUpCount[ iPlayer ] > 0 ){

            ShowSyncHudMsg( iPlayer, syncHudObj, "Coins [%d/%d]^n%d UP", g_iCoinCount[ iPlayer ], iCoinMax, g_iUpCount[ iPlayer ] );

        }else {

            ShowSyncHudMsg( iPlayer, syncHudObj, "Coins [%d/%d]", g_iCoinCount[ iPlayer ], iCoinMax );
        }

    }

}


public playerRespawn( iTaskId ){

    new iPlayer = iTaskId - TASKID_PLAYER_RESPAWN;

    if ( !is_player( iPlayer ) || is_user_alive( iPlayer ) || cs_get_user_team( iPlayer ) == CS_TEAM_SPECTATOR ) 
        return PLUGIN_HANDLED;

    ExecuteHam( Ham_CS_RoundRespawn, iPlayer );

    set_hudmessage( 255, 255, 0, -1.0, 0.25, 0, 6.0 );
    ShowSyncHudMsg( iPlayer, syncHudObj2, "You used 1UP !" );

    emit_sound( iPlayer, CHAN_ITEM, g_soundRespawned, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );

    remove_task( iTaskId );

    return PLUGIN_HANDLED;

}

public client_connect( id ){

    new szAuthid[32];
    get_user_authid( id, szAuthid, charsmax( szAuthid ) );

    new szVaultKey[32], szCoinVault[3], szUpVault[3];

    formatex( szVaultKey, charsmax( szVaultKey ), "MC_%s", szAuthid );
    nvault_get( g_iCoinVault, szVaultKey, szCoinVault, 2 );
    nvault_get( g_iUpVault, szVaultKey, szUpVault, 2 );

    g_iCoinCount[ id ] = str_to_num( szCoinVault );
    g_iUpCount[ id ] = str_to_num( szUpVault );
    g_bPickUp[ id ] = true;

}

public client_disconnected( iPlayer ){

    if ( task_exists( iPlayer + TASKID_PLAYER_RESPAWN )){
        g_iUpCount[ iPlayer ] ++;
        remove_task( iPlayer + TASKID_PLAYER_RESPAWN );
    }

    new szAuthid[32];
    get_user_authid( iPlayer, szAuthid, charsmax( szAuthid ) );

    new szVaultKey[32], szVaultCoin[3], szVaultUp[3];

    formatex( szVaultKey, charsmax( szVaultKey ), "MC_%s", szAuthid );
    formatex( szVaultCoin, 2, "%d", g_iCoinCount[ iPlayer ] );
    formatex( szVaultUp, 2, "%d", g_iUpCount[ iPlayer ] );

    nvault_set( g_iCoinVault, szVaultKey, szVaultCoin );
    nvault_set( g_iUpVault, szVaultKey, szVaultUp );

} 

