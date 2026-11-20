package substates;

import backend.Mods;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import states.MenuMarathon;

using StringTools;

class Marathon_Edit extends MusicBeatSubstate
{
    private var grpSongs:FlxTypedGroup<Alphabet>;

    public static var curSelected:Int = 0;

    var goingBack:Bool = false;
	public var targetY:Float = 0;

    var camLerp:Float = 0.16;

    var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(1, FlxG.height, FlxColor.BLACK);

    public function new()
    {
        super();

		add(blackBarThingie);
        blackBarThingie.scrollFactor.set();
        blackBarThingie.scale.x = 0;
        FlxTween.tween(blackBarThingie, { 'scale.x': 900}, 0.5, { ease: FlxEase.expoOut});

        grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

        updateText();

        new FlxTimer().start(0.1, function(tmr:FlxTimer)
            {
                selectable = true;
            });
    }

    var selectable:Bool = false;

    override function update(elapsed:Float)
    {
        super.update(elapsed);

		var bullShit:Int = 0;

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

				var scaledY = FlxMath.remapToRange(item.targetY, 0, 1, 0, 1.3);

				item.y = FlxMath.lerp(item.y, (scaledY * 120) + (FlxG.height * 0.5), 0.16/(ClientPrefs.data.framerate / 60));
				item.x = FlxMath.lerp(item.x, (targetY * 0), 0.16/(ClientPrefs.data.framerate / 60));
				item.x += 38/(ClientPrefs.data.framerate / 60);
		}

        blackBarThingie.screenCenter();

        if (selectable && !goingBack)
        {
            if (controls.UI_UP_P)
            {
                FlxG.sound.play(Paths.sound('scrollMenu'), 100);
                changeSelection(-1);
            }
    
            if (controls.UI_DOWN_P)
            {
                FlxG.sound.play(Paths.sound('scrollMenu'), 100);
                changeSelection(1);
            }

            if (controls.BACK)
                {
                    goingBack = true;
                    FlxG.sound.play(Paths.sound('cancelMenu'), 100);
                    FlxTween.tween(blackBarThingie, { 'scale.x': 0}, 0.5, { ease: FlxEase.expoIn});
                    for (item in grpSongs.members)
                        {
                            FlxTween.tween(item, { 'scale.x': 0}, 0.5, { ease: FlxEase.expoIn});
                        }
                    new FlxTimer().start(0.6, function(tmr:FlxTimer)
                        {
                            FlxG.state.closeSubState();
                            FlxG.state.openSubState(new Marathon_Substate());
                        });
                }
        
            if (controls.ACCEPT)
            {
                PlayState.storyPlaylist.remove(PlayState.storyPlaylist[curSelected]);
                PlayState.difficultyPlaylist.remove(PlayState.difficultyPlaylist[curSelected]);
                if (PlayState.storyFolderPlaylist.length > curSelected)
                    PlayState.storyFolderPlaylist.remove(PlayState.storyFolderPlaylist[curSelected]);

                FlxG.sound.play(Paths.sound('confirmMenu'), 100);

                MenuMarathon.saveCurrent();

                grpSongs.clear();

                updateText();
                
            }
        }
    }

    function changeSelection(change:Int = 0)
        {
    
            // NGio.logEvent('Fresh');
            FlxG.sound.play(Paths.sound('scrollMenu'), 100);
    
            curSelected += change;
    
            if (curSelected < 0)
                curSelected = PlayState.storyPlaylist.length - 1;
            if (curSelected >= PlayState.storyPlaylist.length)
                curSelected = 0;
    
            var bullShit:Int = 0;
    
            for (item in grpSongs.members)
            {
                item.targetY = bullShit - curSelected;
                bullShit++;
    
                item.alpha = 0.6;
                // item.setGraphicSize(Std.int(item.width * 0.8));
    
                if (item.targetY == 0)
                {
                    item.alpha = 1;
                    // item.setGraphicSize(Std.int(item.width));
                }
            }
        }

    function updateText()
    {
        for (i in 0...PlayState.storyPlaylist.length)
            {
    
                var songLabel:String = PlayState.storyPlaylist[i];
                if (PlayState.storyFolderPlaylist.length > i
                    && PlayState.storyFolderPlaylist[i] != null
                    && PlayState.storyFolderPlaylist[i].length > 0
                    && PlayState.storyFolderPlaylist[i] != Mods.BASE_GAME_MOD_FOLDER)
                    songLabel += ' [' + PlayState.storyFolderPlaylist[i] + ']';
                var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songLabel, true);
    
                var sprDifficulty:FlxSprite;
    
                var diffTex = Paths.getSparrowAtlas('difficulties');
                sprDifficulty = new FlxSprite(0, 50);
                sprDifficulty.frames = diffTex;
                sprDifficulty.animation.addByPrefix('noob', 'NOOB');
                sprDifficulty.animation.addByPrefix('easy', 'EASY');
                sprDifficulty.animation.addByPrefix('normal', 'NORMAL');
                sprDifficulty.animation.addByPrefix('hard', 'HARD');
                sprDifficulty.animation.addByPrefix('expert', 'EXPERT');
                sprDifficulty.animation.addByPrefix('insane', 'INSANE');
                sprDifficulty.animation.addByPrefix('crazy', 'CRAZY');
                sprDifficulty.animation.addByPrefix('flip', 'FLIP');
                sprDifficulty.animation.addByPrefix('fucked', 'FUCKED');
                sprDifficulty.animation.addByPrefix('hell', 'HELL');
                sprDifficulty.animation.addByPrefix('remix', 'REMIX');

                var difficulty:String = PlayState.difficultyPlaylist[i];
                var animationName:String = difficulty.toLowerCase();
                switch (animationName)
                {
                    case '0':
                        animationName = 'noob';
                    case '1':
                        animationName = 'easy';
                    case '2':
                        animationName = 'normal';
                    case '3':
                        animationName = 'hard';
                    case '4':
                        animationName = 'expert';
                    case '5':
                        animationName = 'insane';
                }

                switch (animationName)
                {
                    case 'noob', 'easy', 'normal', 'hard', 'expert', 'insane', 'crazy', 'flip', 'fucked', 'hell', 'remix':
                        sprDifficulty.animation.play(animationName);
                        songText.add(sprDifficulty);
                    default:
                        var diffText:FlxText = new FlxText(0, 50, 220, difficulty.toUpperCase(), 18);
                        diffText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
                        diffText.setBorderStyle(OUTLINE, 0xFF000000, 2, 1);
                        diffText.x = -diffText.width / 2;
                        songText.add(diffText);
                }
    
                // songText.itemType = "Vertical";
                songText.targetY = i;
                // songText.targetX = -9;
                grpSongs.add(songText);
            }

        if (curSelected >= PlayState.storyPlaylist.length)
            curSelected = PlayState.storyPlaylist.length - 1;
        if (curSelected < 0)
            curSelected = 0;

        var bullShit:Int = 0;
    
            for (item in grpSongs.members)
            {
                item.targetY = bullShit - curSelected;
                bullShit++;
    
                item.alpha = 0.6;
                // item.setGraphicSize(Std.int(item.width * 0.8));
    
                if (item.targetY == 0)
                {
                    item.alpha = 1;
                    // item.setGraphicSize(Std.int(item.width));
                }
            }
    }
}