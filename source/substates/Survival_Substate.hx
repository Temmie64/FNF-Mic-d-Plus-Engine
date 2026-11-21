package substates;

import backend.Mods;
import backend.Song;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import states.MenuSurvival;
import states.PlaySelectionState;
import sys.FileSystem;

class Survival_Substate extends MusicBeatSubstate
{
	public static var curSelected:Int = 0;
	public static var presets:Array<String>;

	var menuItems:FlxTypedGroup<FlxSprite>;
	var optionNames:Array<String>;
	var selectable:Bool = false;
	var closing:Bool = false;

	public function new()
	{
		super();
		if (!FileSystem.isDirectory('presets/survival'))
			FileSystem.createDirectory('presets/survival');

		presets = [];
		try
		{
			presets = FileSystem.readDirectory('presets/survival');
			presets.remove('current');
		}
		catch (_:Dynamic) {}

		var canPlay:String = PlayState.storyPlaylist.length > 0 && PlayState.difficultyPlaylist.length > 0 ? 'play' : 'no';
		var canEdit:String = PlayState.storyPlaylist.length > 0 ? 'edit' : 'no';
		optionNames = [canPlay, canEdit, 'clear', 'save', presets.length > 0 ? 'load' : 'no', 'options', 'exit'];
		curSelected = Std.int(FlxMath.bound(curSelected, 0, optionNames.length - 1));

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);
		var atlas = Paths.getSparrowAtlas('MicUp/Modi_Buttons');
		for (i in 0...optionNames.length)
		{
			var item:FlxSprite = new FlxSprite(0, 10 + (i * 95));
			item.frames = atlas;
			item.animation.addByPrefix('idle', optionNames[i], 24, true);
			item.animation.play('idle');
			item.ID = i;
			item.scrollFactor.set();
			item.antialiasing = true;
			item.screenCenter(X);
			menuItems.add(item);
		}
		selectable = true;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (!selectable || closing)
			return;

		if (controls.UI_UP_P)
		{
			changeItem(-1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 100);
		}
		if (controls.UI_DOWN_P)
		{
			changeItem(1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 100);
		}
		if (controls.BACK)
		{
			closing = true;
			FlxG.sound.play(Paths.sound('cancelMenu'), 100);
			FlxG.state.closeSubState();
			MenuSurvival.substated = false;
		}
		if (controls.ACCEPT)
			acceptOption();

		for (item in menuItems.members)
		{
			item.scale.set(FlxMath.lerp(item.scale.x, item.ID == curSelected ? 1.0 : 0.4, 0.16),
				FlxMath.lerp(item.scale.y, item.ID == curSelected ? 1.0 : 0.4, 0.16));
			item.screenCenter(X);
			item.y = 10 + (item.ID * 95);
		}
	}

	function changeItem(change:Int):Void
	{
		curSelected += change;
		if (curSelected < 0)
			curSelected = optionNames.length - 1;
		if (curSelected >= optionNames.length)
			curSelected = 0;
	}

	function acceptOption():Void
	{
		switch (optionNames[curSelected])
		{
			case 'play':
				if (PlayState.storyPlaylist.length > 0 && PlayState.difficultyPlaylist.length > 0)
				{
					var diff:Int = Std.parseInt(PlayState.difficultyPlaylist[0]);
					var suffix:String = difficultySuffix(diff);
					PlayState.storyDifficulty = diff;
					Mods.currentModDirectory = PlayState.storyFolderPlaylist.length > 0
						? PlayState.storyFolderPlaylist[0]
						: '';
					var songName:String = PlayState.storyPlaylist[0].toLowerCase();
					if (Song.loadFromJson(songName + suffix, songName) != null)
					{
						closing = true;
						PlayState.campaignScore = 0;
						FlxG.sound.play(Paths.sound('confirmMenu'), 100);
						FlxG.state.closeSubState();
						FlxG.state.openSubState(new ChartType());
						MenuSurvival.no = true;
					}
					else
						FlxG.sound.play(Paths.sound('cancelMenu'), 100);
				}
			case 'edit':
				closing = true;
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new Survival_Edit());
			case 'clear':
				PlayState.storyPlaylist = [];
				PlayState.difficultyPlaylist = [];
				PlayState.storyFolderPlaylist = [];
				MenuSurvival.saveCurrent();
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new Survival_Substate());
			case 'save':
				closing = true;
				Substate_PresetSave.coming = 'Survival';
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new Substate_PresetSave());
			case 'load':
				closing = true;
				Substate_PresetLoad.coming = 'Survival';
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new Substate_PresetLoad());
			case 'options':
				closing = true;
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new Survival_GameOptions());
			case 'exit':
				closing = true;
				FlxG.sound.play(Paths.sound('confirmMenu'), 100);
				MusicBeatState.switchState(new PlaySelectionState());
		}
	}

	function difficultySuffix(diff:Int):String
	{
		return switch (diff)
		{
			case 0: '-noob';
			case 1: '-easy';
			case 3: '-hard';
			case 4: '-expert';
			case 5: '-insane';
			default: '';
		}
	}
}
