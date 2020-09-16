script "clan_slimetube";

import <zlib.ash>;
import <DungeonKeeper.ash>;

record SlimeInfo {
    int percentage;
    int tickles;
    int squeezes;
    int slimes;
    string boss_status;
};

string to_string( SlimeInfo l )
{
    string result = `<div style="border: 1px solid; padding: 5px; margin-bottom: 15px;">`;

    if ( l.boss_status != "" )
    {
        result += l.boss_status;
    }
    else
    {
        result += `{l.percentage}0% complete<br />{l.slimes} slime(s) defeated<br />{l.tickles} tickle(s)<br />{l.squeezes} squeeze(s)`;
    }

    return `{result}</div>`;
}

string get_summary( DungeonAction [int] actions, int percentage )
{
    SlimeInfo summary = new SlimeInfo( percentage );

    foreach i, action in actions
    {
        DungeonActionType action_type = action.get_type();

        switch ( action_type.type )
        {
            case "combat":
                monster mon = action.info.to_monster();
                if ( mon == $monster[Mother Slime] )
                {
                    summary.boss_status = `{mon} killed by {action.user_name}`;
                }
                else
                {
                    summary.slimes += 1;
                }
                break;
            case "tickle":
                summary.tickles += 1;
                break;
            case "squeeze":
                summary.squeezes += 1;
                break;
        }
    }

    return summary.to_string();
}

void main()
{   
    DungeonLogs logs = parse_logs( "slimetube" );

    buffer page = visit_url();

    int percentage = page.excise( "slimetube/tube_", ".gif" ).to_int();

    string search = `<b>The Slime Tube</b></td></tr><tr><td style="padding: 5px; border: 1px solid blue;"><center><table><tr><td>`;

    page.replace_string( search, `{search}<div style="display: flex; flex-wrap: wrap; justify-content: center;"><div style="margin: 5px 15px 15px 0;"><h4>{get_clan_name()}</h4>{get_summary( logs.actions, percentage )}</div><div>` );

    write(page);
}