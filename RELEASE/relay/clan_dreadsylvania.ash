script "clan_dreadsylvania";

import <zlib.ash>;
import <DungeonKeeper.ash>;

record DreadZoneInfo {
    location loc;
    int sheets_needed;
    int [string] ratio;
    int progress;
    string boss_status;
    int [string] banishes;
};

float round( float number, int place )
{
    return round( number * 10.0**place ) / 10.0**place;
}

string infobox( string contents )
{
    return `<div style="border: 1px solid; padding: 5px; margin-bottom: 15px;">{contents}</div>`;
}

string to_string( DreadZoneInfo l )
{
    string result = `<div><b>{l.loc}</b></div>`;

    if ( l.sheets_needed > 0 )
    {
        result += `Carriageman needs {l.sheets_needed} more sheets`;
    }
    else if ( l.boss_status != "" )
    {
        result += l.boss_status;
    }
    else
    {
        string [int] ratio;
        foreach t, i in l.ratio
        {
            ratio[count(ratio)] = `{round( ( i / l.progress.to_float() ) * 100, 2 )}% {t}`;
        }
        string ratio_string = ratio.join(", ");

        string [int] banishes;
        foreach t, i in l.banishes
        {
            banishes[count(banishes)] = `{i} {DREAD_MONSTER_TYPES[ t ].singular}`;
        }
        string banishes_string = count(banishes) > 0 ? `<br />with {banishes.join(" and ")} banish(es)` : '';

        result += `{l.progress } / 1000<br />{ratio_string}{banishes_string}`;
    }

    return infobox(result);
}

string get_actions( DungeonAction [int] actions )
{
    string result = `<form><div style="display: flex;"><div style="flex: 0 0;"><button type="button" style="padding: 0;" onclick="window.location.href = window.location.pathname;">🔁</button></div><div style="flex: 1 1;"><select name="dungeon_action" value="-1" style="max-width: 150px;"><option value="-1">Select an action...</option>`;

    DungeonActionType [int] possible_actions = actions.possible_actions( "Dreadsylvania" );

    sort possible_actions by value.to_readable();

    foreach i, action_type in possible_actions
    {
        DungeonActionRequirement requirement = action_type.find_requirement();

        string [int] need;
        if ( requirement.required_items.count() > 0 )
        {
            foreach it in requirement.required_items if ( it.item_amount() < 1 )
            {
                need[need.count()] = it.to_string();
            }
        }

        result += `<option value="{action_type.get_id()}"{need.count() > 0 ? " disabled" : ""}>{action_type.to_readable()}{need.count() > 0 ? ` (need {need.join( ", " )})` : ""}</option>`;
    }
    result += `</select></div><div style="flex: 0 0"><input type="submit" value="Do it" /></div></div></form>`;

    return result;
}

string get_summary( DungeonLogs logs )
{
    DreadZoneInfo [location] zones = {
        $location[Dreadsylvanian Woods]: new DreadZoneInfo( $location[Dreadsylvanian Woods], 0 ),
        $location[Dreadsylvanian Village]: new DreadZoneInfo( $location[Dreadsylvanian Village], 1000 ),
        $location[Dreadsylvanian Castle]: new DreadZoneInfo( $location[Dreadsylvanian Castle], 2000 ),
    };

    foreach i, action in logs.actions
    {
        DungeonActionType action_type = action.get_type();

        location loc = action.get_location();

        switch ( action_type.type )
        {
            case "combat":
                monster mon = action.info.to_monster();
                if ( DREAD_BOSSES contains mon )
                {
                    zones[ loc ].boss_status = `{mon} killed by {action.user_name}`;
                }
                else
                {
                    string [int] detail_pieces = mon.to_string().split_string( " " );
                    zones[ loc ].progress += 1;
                    zones[ loc ].ratio[ detail_pieces[ 1 ] ] += 1;
                }
                break;
            case "banish":
                if ( DREAD_MONSTER_TYPES contains action_type.detail )
                {
                    zones[ DREAD_MONSTER_TYPES[ action_type.detail ].loc ].banishes[ action_type.detail ] += 1;
                }
                break;
            case "carriageman":
                int sheets = action.info.to_int();
                foreach l, zone in zones
                {
                    zone.sheets_needed = max( zone.sheets_needed - sheets, 0 );
                }
                break;
        }
    }

    string meta = infobox( `<div><b>Overall</b></div>{logs.meta["kisses"]} kisses` );

    return `{meta}{zones[$location[Dreadsylvanian Woods]].to_string()}{zones[$location[Dreadsylvanian Village]].to_string()}{zones[$location[Dreadsylvanian Castle]].to_string()}`;
}

string run_action()
{
    string [string] ff = form_fields();

    if ( !( ff contains "dungeon_action" ) )
    {
        return "";
    }

    int id = ff["dungeon_action"].to_int();

    if ( id == -1 )
    {
        return "";
    }

    DungeonActionType dat = ACTION_TYPES[id];
    DungeonActionResult result = dat.run();

    return `<div style="margin-bottom: 5px;">{dat.to_readable()} {result.success ? "successful" : "not successful"}</div>`;
}

void main()
{
    string action_result = run_action();
    
    DungeonLogs logs = parse_logs( "Dreadsylvania" );

    buffer page = visit_url();

    string search = `<b>Dreadsylvania</b></td></tr><tr><td style="padding: 5px; border: 1px solid blue;"><center><table><tr><td>`;

    page.replace_string( search, `{search}<div style="display: flex; flex-wrap: wrap; justify-content: center;"><div style="margin: 5px 15px 15px 0;"><h4>{get_clan_name()}</h4>{get_summary( logs )}{get_actions( logs.actions )}{action_result}</div><div>` );

    write(page);
}