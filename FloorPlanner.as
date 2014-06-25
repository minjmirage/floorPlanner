package 
{
	import flash.display.Sprite;
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Vector3D;
	import flash.geom.Rectangle;
	import flash.utils.getTimer;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.filters.DropShadowFilter;
	
	[SWF(width = "800", height = "600", backgroundColor = "#FFFFFF", frameRate = "30")];
	
	/**
	 * ...
	 * @author mj
	 */
	public class FloorPlanner extends Sprite 
	{
		private var Copy:XML = 
		<Copy>
		<TopBar>
			<btn ico="" en="NEW" cn="" />
			<btn ico="" en="OPEN" cn="" />
			<btn ico="" en="SAVE" cn="" />
			<btn ico="" en="UNDO" cn="" />
			<btn ico="" en="REDO" cn="" />
			<btn ico="" en="UPLOAD DESIGN" cn="" />
			<btn ico="" en="RULER" cn="" />
		</TopBar>
		<Items>
			<item en="LCD TV" cn="" cls="TVFlat" />
			<item en="Toilet Bowl" cn="" cls="Toilet" />
			<item en="Square Table" cn="" cls="TableSquare" />
			<item en="Round Table" cn="" cls="TableRound" />
			<item en="Rectangular Table" cn="" cls="TableRect" />
			<item en="Octagonal Table" cn="" cls="TableOctagon" />
			<item en="Corner Table" cn="" cls="TableL" />
			<item en="Stove" cn="" cls="Stove" />
			<item en="2 Seat Sofa" cn="" cls="Sofa2" />
			<item en="3 Seat Sofa" cn="" cls="Sofa3" />
			<item en="4 Seat Sofa" cn="" cls="Sofa4" />
			<item en="Round Sink" cn="" cls="SinkRound" />
			<item en="Kitchen Sink" cn="" cls="SinkKitchen" />
			<item en="Piano" cn="" cls="Piano" />
			<item en="Oven" cn="" cls="Oven" />
			<item en="Chair" cn="" cls="Chair" />
			<item en="Singale Bed" cn="" cls="BedSingle" />
			<item en="Double Bed" cn="" cls="BedDouble" />
			<item en="Round Bathtub" cn="" cls="BathTubRound" />
			<item en="Corner Bathtub" cn="" cls="BathTubL" />
			<item en="Bathtub" cn="" cls="BathTub" />
			<item en="Armchair" cn="" cls="ArmChair" />
		</Items>
		</Copy>;
	
		private var mouseDownPt:Vector3D = null;		// point of last mouseDown
		private var mouseUpPt:Vector3D= null;			// point of last mouseUp
		private var grid:WireGrid = null;				
		private var floorPlan:FloorPlan = null;			
		
		private var undoStk:Vector.<String> = null;		// stack of JSON states
		private var redoStk:Vector.<String> = null;		// stack of JSON states
		
		private var topBar:Sprite = null;
		private var menu:Sprite = null;
		private var scaleSlider:Sprite = null;
		
		private var stepFn:Function = null;				// to exec every frame
		private var mouseDownFn:Function = null;		// to exec
		private var mouseUpFn:Function = null;			// to exec
		
		//=============================================================================================
		//
		//=============================================================================================
		public function FloorPlanner():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}//
		
		//=============================================================================================
		// Entry point
		//=============================================================================================
		private function init(e:Event=null):void 
		{
			stage.scaleMode = "noScale";
			stage.align = "topLeft";
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			mouseDownPt = new Vector3D();
			mouseUpPt = new Vector3D();
			
			var sw:int = stage.stageWidth;
			var sh:int = stage.stageHeight;
			
			undoStk = new Vector.<String>();
			redoStk = new Vector.<String>();
			
			// ----- add grid background
			grid = new WireGrid(sw,sh);
			grid.x = sw/2;
			grid.y = sh/2;
			grid.update();
			addChild(grid);
			
			// ----- drawing sprite
			floorPlan = new FloorPlan();
			grid.addChild(floorPlan.overlay);
			
			// ----- create top bar
			topBar = new TopBarMenu(Copy.TopBar.btn,function (i:int):void 
			{
				prn("TopBarMenu "+i);
				if (i==0)		// new 
				{}
				else if (i==1)	// open
				{}
				else if (i==2)	// save
				{
					
				}
				else if (i==3)	// undo
				{
					if (undoStk.length>0)
					{
						redoStk.push(floorPlan.exportData());
						prn("undo:" +undoStk[undoStk.length-1]);
						floorPlan.importData(undoStk.pop());
					}
				}
				else if (i==4)	// redo
				{
					if (redoStk.length>0)
					{
						undoStk.push(floorPlan.exportData());
						prn("undo:" +redoStk[redoStk.length-1]);
						floorPlan.importData(redoStk.pop());
					}
				}
				else if (i==5)	// upload
				{}
			});
			addChild(topBar);
			
			// ----- zoom slider
			scaleSlider = createVSlider(["1x","2x","3x","4x","5x"],function(f:Number):void {grid.zoom(f*4+1);});
			scaleSlider.x = stage.stageWidth/20;
			scaleSlider.y = stage.stageHeight/20 + topBar.height;
			addChild(scaleSlider);
						
			// ----- enter default editing mode
			modeDefault();
			
			// ----- create default room walls
			createDefaRoom();
			
			// ----- add controls
			stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		}//endfunction
		
		//=============================================================================================
		// default room to look at just so it wouldnt be too boring 
		//=============================================================================================
		private function createDefaRoom():void
		{
			floorPlan.createWall(new Point( -250, -200), new Point(250, -200),20);
			floorPlan.createWall(new Point( 250, -200), new Point(250, 180),20);
			floorPlan.createWall(new Point( 250, 180), new Point( 150, 180),20);
			floorPlan.createWall(new Point( 150, 180), new Point( 50, 230),10);
			floorPlan.createWall(new Point( 50, 230), new Point( -50, 230),10);
			floorPlan.createWall(new Point(-50, 230), new Point(-150, 180),10);
			floorPlan.createWall(new Point(-150, 180), new Point(-250, 180),20);
			floorPlan.createWall(new Point( -250, 180), new Point( -250, -200), 20);
			floorPlan.Walls[0].Doors.push(new Door(0.35, 0.3));
			floorPlan.refresh();
		}//endfunction
		
		//=============================================================================================
		// go into defacto mode
		//=============================================================================================
		private function modeDefault():void
		{
			//prn("modeDefault");
			var px:int = 0;
			var py:int = topBar.height+5;
			
			// ---------------------------------------------------------------------
			function showMainMenu():void
			{
				if (menu!=null)
				{
					if (menu.parent!=null) menu.parent.removeChild(menu);
					px = menu.x;
					py = menu.y;
				}
				menu = new ButtonsMenu("EDITING MODE",
										Vector.<String>(["ADD WALLS","ADD DOORS","ADD WINDOWS","ADD FURNITURE"]),
										Vector.<Function>([modeAddWalls,modeAddDoors,modeAddWindows,modeAddFurniture]));
				if (px==0)	px = stage.stageWidth-menu.width;
				menu.x = px;
				menu.y = py;
				stage.addChild(menu);
			}
			// ---------------------------------------------------------------------
			function showWallProperties(wall:Wall):void
			{
				if (menu!=null)
				{
					if (menu.parent!=null) menu.parent.removeChild(menu);
					px = menu.x;
					py = menu.y;
				}
				menu = new ButtonsMenu("PROPERTIES",
										Vector.<String>(["THICKNESS ["+wall.thickness+"]","REMOVE"]),
										Vector.<Function>([	function(val:String):void 
															{
																wall.thickness = Math.max(5,Math.min(30,Number(val)));
															},
															function():void 
															{
																floorPlan.removeWall(wall);
																floorPlan.refresh();
																showMainMenu();
															}]));
				menu.x = px;
				menu.y = py;
				stage.addChild(menu);
			}
			// ---------------------------------------------------------------------
			
			showMainMenu();
			
			// ----- default editing logic
			var snapDist:Number = 10;
			var prevMousePt:Point = new Point(0,0);
			stepFn = function():void
			{
				if (mouseDownPt.w>mouseUpPt.w)	// is dragging
				{
					if (floorPlan.selected is Point)
					{	// ----- shift joint
						var selJ:Point = (Point)(floorPlan.selected); 
						selJ.x = grid.mouseX;
						selJ.y = grid.mouseY;
						var snapJ:Point = floorPlan.nearestJoint(selJ, snapDist);		// chk if near any joint
						if (snapJ!=null)	// snap end to joint
						{
							if  (snapJ!=selJ)
							{
								floorPlan.replaceJointWith(selJ,snapJ);
								floorPlan.selected = null;
							}
						}
						else	// joint wall end to existing wall
						{
							var snapW:Wall = floorPlan.nearestWall(selJ, snapDist);
							if (snapW!=null && snapW.joint1!=selJ && snapW.joint2!=selJ)
							{
								floorPlan.removeWall(snapW);
								floorPlan.createWall(snapW.joint1, selJ);
								floorPlan.createWall(snapW.joint2, selJ);
								floorPlan.selected = null;
							}
						}
						floorPlan.refresh();
					}
					else if (floorPlan.selected is Wall)
					{	// ----- shift wall
						var selW:Wall = (Wall)(floorPlan.selected);
						selW.joint1.x += grid.mouseX - prevMousePt.x;
						selW.joint1.y += grid.mouseY - prevMousePt.y;
						selW.joint2.x += grid.mouseX - prevMousePt.x;
						selW.joint2.y += grid.mouseY - prevMousePt.y;
						floorPlan.refresh();
					}
					else if (floorPlan.selected!=null)
					{	// ----- furniture shifting... 
					}
					else 
					{	// ----- shift grid background
						grid.x += (grid.mouseX - prevMousePt.x)*grid.scaleX;
						grid.y += (grid.mouseY - prevMousePt.y)*grid.scaleY;
						grid.update();
					}
					prevMousePt.x = grid.mouseX;
					prevMousePt.y = grid.mouseY;
				}
			}
			mouseDownFn = function():void
			{
				prevMousePt.x = grid.mouseX;
				prevMousePt.y = grid.mouseY;
				
				floorPlan.mouseSelect();				// chk if anything selected
				
				if (floorPlan.selected!=null)			// save for undo
					undoStk.push(floorPlan.exportData());
				
				if (floorPlan.selected is Point)		// selected a joint
				{	}
				else if (floorPlan.selected is Wall)	// selected a wall
					showWallProperties((Wall)(floorPlan.selected));
				else if (floorPlan.selected!=null)		// selected a furniture
				{ 	}
				else
					showMainMenu();
			}
			mouseUpFn = function():void
			{
				if (undoStk.length>0 && floorPlan.exportData()==undoStk[undoStk.length-1]) 
					undoStk.pop();	// if no state change 
			}
		}//endfunction
		
		//=============================================================================================
		// go into adding furniture mode
		//=============================================================================================
		private function modeAddFurniture():void
		{
			var px:int = 0;
			var py:int = 0;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new ButtonsMenu("ADDING FURNITURE",
									Vector.<String>(["DONE"]),
									Vector.<Function>([modeDefault]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
			
			var fmenu:Sprite = new AddFurnitureMenu(Copy.Items[0],floorPlan);
			fmenu.y = menu.height+10;
			menu.addChild(fmenu);
			
			var curItem:Sprite = null;
			stepFn = function():void	{}
			mouseDownFn = floorPlan.mouseSelect;
			mouseUpFn = function():void	{}
		}//endfunction
		
		//=============================================================================================
		// go into adding walls mode
		//=============================================================================================
		private function modeAddWalls(snapDist:Number=10):void
		{
			var px:int = 0;
			var py:int = 0;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new ButtonsMenu("ADDING WALLS",
									Vector.<String>(["DONE"]),
									Vector.<Function>([modeDefault]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
		
			// ----- add walls logic
			var wall:Wall = null;
			stepFn = function():void
			{
				if (wall!=null)
				{
					wall.joint2.x = grid.mouseX;
					wall.joint2.y = grid.mouseY;
					
					var snapJ:Point = floorPlan.nearestJoint(wall.joint2, snapDist);		// chk if near any joint
					if (snapJ!=null && snapJ!=wall.joint1)	
					{	// snap to another wall joint
						if  (snapJ!=wall.joint2)
						{
							floorPlan.replaceJointWith(wall.joint2,snapJ);
							wall = null;
						}
					}
					else
					{
						var collided:Wall = floorPlan.chkWallCollide(wall);
						if (collided != null)
						{
							var intercept:Point = floorPlan.projectedWallPosition(collided, wall.joint2);
							floorPlan.removeWall(collided);
							floorPlan.createWall(collided.joint1, intercept,snapDist);
							floorPlan.createWall(collided.joint2, intercept, snapDist);
							floorPlan.removeWall(wall);
							floorPlan.createWall(wall.joint1, intercept,snapDist);
							wall = null;
						}
					}
					floorPlan.refresh();
				}
			}
			mouseDownFn = function():void
			{
				if (wall==null)
					wall = floorPlan.createWall(new Point(grid.mouseX,grid.mouseY),
												new Point(grid.mouseX,grid.mouseY),
												snapDist);
			}
			mouseUpFn = function():void
			{
				if (wall!=null && wall.joint1.subtract(wall.joint2).length<=snapDist)
				{
					floorPlan.removeWall(wall);		// remove wall stub
					floorPlan.refresh();
				}
				wall = null;
			}
		}//endfunction
		
		//=============================================================================================
		// go into adding doors mode
		//=============================================================================================
		private function modeAddDoors(snapDist:Number=10):void
		{
			var px:int = 0;
			var py:int = 0;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new ButtonsMenu("ADDING DOORS",
									Vector.<String>(["DONE"]),
									Vector.<Function>([modeDefault]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
			
			// ----- add doors logic
			var prevWall:Wall = null;
			var door:Door = null;
			stepFn = function():void
			{
				// ----- remove added display door
				if (prevWall!=null)
				{	
					if (prevWall.Doors.indexOf(door)!=-1)
						prevWall.Doors.splice(prevWall.Doors.indexOf(door),1);
					floorPlan.drawWall(prevWall);
				}
				
				var mouseP:Point = new Point(grid.mouseX,grid.mouseY);
				
				var near:Wall = floorPlan.nearestWall(mouseP,snapDist);
				var doorP:Point = null;
				if (near!=null)	doorP = chkPlaceDoor(near, mouseP, 100);	// chk place door of 100 width
				// ----- if in position to place door
				if (near!=null && doorP!=null)
				{
					if (door==null) 	
						door = new Door(doorP.x,doorP.y-doorP.x);
					else
						door.pivot = doorP.x;
					
					near.Doors.push(door);
					prevWall = near;
					floorPlan.drawWall(near);
				}
				// ----- if not in legal position to show door
			}//endfunction
			mouseDownFn = function():void
			{
				
			}
			mouseUpFn = function():void
			{
				prevWall = null;	// forget about the last placed door
				door = null;
			}
		}//endfunction
		
		//=============================================================================================
		// go into adding doors mode
		//=============================================================================================
		private function modeAddWindows(snapDist:Number=10):void
		{
			var px:int = 0;
			var py:int = 0;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new ButtonsMenu("ADDING WINDOWS",
									Vector.<String>(["DONE"]),
									Vector.<Function>([modeDefault]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
			
			// ----- add doors logic
			var prevWall:Wall = null;
			var door:Door = null;
			stepFn = function():void
			{
				// ----- remove added display door
				if (prevWall!=null)
				{	
					if (prevWall.Doors.indexOf(door)!=-1)
						prevWall.Doors.splice(prevWall.Doors.indexOf(door),1);
				}
				
				var mouseP:Point = new Point(grid.mouseX,grid.mouseY);
				
				var near:Wall = floorPlan.nearestWall(mouseP,snapDist);
				var doorP:Point = null;
				if (near!=null)	doorP = chkPlaceDoor(near, mouseP, 60);	// chk place door of 60 width
				// ----- if in position to place door
				if (near!=null && doorP!=null)
				{
					if (door == null) 
					{
						door = new Door(doorP.x, doorP.y - doorP.x);
						door.angR = 0;
						door.thickness = 20;
					}
					else
						door.pivot = doorP.x;
					
					near.Doors.push(door);
					prevWall = near;
				}
				// ----- if not in legal position to show door
			}//endfunction
			mouseDownFn = function():void
			{
				
			}
			mouseUpFn = function():void
			{
				prevWall = null;	// forget about the last placed door
				door = null;
			}
		}//endfunction
		
		//=============================================================================================
		// returns whether door of width can be placed at position pt along given wall 
		//=============================================================================================
		private function chkPlaceDoor(wall:Wall, pt:Point, width:Number):Point
		{
			var wallV:Point = wall.joint2.subtract(wall.joint1);
			var wallL:Number = wallV.length;
			wallV.normalize(1);
			var proj:Number = (pt.x-wall.joint1.x)*wallV.x + (pt.y-wall.joint1.y)*wallV.y;	// ratio along wall where door is at
			var a:Number = proj/wallL-0.5*width/wallL;	// door span along wallL
			var b:Number = proj/wallL+0.5*width/wallL;
			if (a<0 || b>1)	return null;	//exceed wall limit
			
			for (var i:int=wall.Doors.length-1; i>-1; i--)		// check if overlap other doors
			{
				var c:Number = wall.Doors[i].pivot;
				var d:Number = wall.Doors[i].dir+c;
				if (d<c)
				{
					var tmp:Number = d;
					d = c;
					c = tmp;
				}
				if ((a>c && a<d) || (b>c && b<d))
					return null;
			}
			return new Point(a,b);
		}//endfunction
		
		//=============================================================================================
		// Main Loop
		//=============================================================================================
		private function onEnterFrame(ev:Event):void
		{
			if (stepFn!=null) stepFn();
		}//endfunction
		
		//=============================================================================================
		//
		//=============================================================================================
		private function onMouseDown(ev:Event):void
		{
			if (topBar!=null && topBar.hitTestPoint(stage.mouseX,stage.mouseY)) return;
			if (menu!=null && menu.hitTestPoint(stage.mouseX,stage.mouseY)) return;
			if (scaleSlider!=null && scaleSlider.hitTestPoint(stage.mouseX,stage.mouseY)) return;
			
			mouseDownPt = new Vector3D(grid.mouseX,grid.mouseY,0,getTimer());
			if (mouseDownFn!=null) mouseDownFn();
		}//endfunction
		
		//=============================================================================================
		//
		//=============================================================================================
		private function onMouseUp(ev:Event):void
		{
			mouseUpPt = new Vector3D(grid.mouseX,grid.mouseY,0,getTimer());
			if (mouseUpFn!=null) mouseUpFn();
		}//endfunction
		
		//=============================================================================================
		// debug printout function
		//=============================================================================================
		private var debugTf:TextField;
		private function prn(s:String):void
		{
			if (debugTf==null)
			{
				debugTf = new TextField();
				debugTf.autoSize = "left";
				debugTf.wordWrap = false;
				debugTf.mouseEnabled = false;
				var tff:TextFormat = debugTf.defaultTextFormat;
				tff.color = 0x000000;
				tff.font = "arial";
				tff.size = 11;
				debugTf.defaultTextFormat = tff;
				debugTf.text = "";
				addChild(debugTf);
			}
		
			debugTf.appendText(s+"\n");
		}//endfunction
		
		//=============================================================================================
		// creates a vertical slider bar of wxh dimensions  
		//=============================================================================================
		private function createVSlider(markings:Array,callBack:Function):Sprite
		{
			var w:int = 5;
			var h:int = 200;
			
			// ----- main sprite
			var s:Sprite = new Sprite();
			s.graphics.beginFill(0xCCCCCC,1);
			s.graphics.drawRect(0,0,w,h);
			s.graphics.endFill();
		
			// ----- slider knob
			var slider:Sprite = new Sprite();
			slider.graphics.beginFill(0xEEEEEE,1);
			slider.graphics.drawCircle(0,0,w);
			slider.graphics.endFill();
			slider.graphics.beginFill(0x333333,1);
			slider.graphics.drawCircle(0,0,w/2);
			slider.graphics.endFill();
			slider.buttonMode = true;
			slider.mouseChildren = false;
			slider.filters = [new DropShadowFilter(2)];
			slider.x = w/2;
			slider.y = h;
			s.addChild(slider);
		
			// ----- draw markings
			s.graphics.lineStyle(0,0xCCCCCC,1);
			var n:int = markings.length;
			for (var i:int=0; i<n; i++)
			{
				s.graphics.moveTo(w/2,h/(n-1)*i);
				s.graphics.lineTo(w*3/2,h/(n-1)*i);
				var tf:TextField = new TextField();
				var tff:TextFormat = tf.defaultTextFormat;
				tff.color = 0x999999;
				tf.defaultTextFormat = tff;
				tf.text = markings[i];
				tf.autoSize = "left";
				tf.wordWrap = false;
				tf.selectable = false;
				tf.x = w*2;
				tf.y = h/(n-1)*(n-1-i)-tf.height/2;
				s.addChild(tf);
			}
		
			function updateHandler(ev:Event):void
			{
				if (callBack!=null) callBack(1-slider.y/h);
			}
			function startDragHandler(ev:Event):void
			{
				if (slider.hitTestPoint(stage.mouseX,stage.mouseY))
					slider.startDrag(false,new Rectangle(slider.x,0,0,h));
				else
					s.startDrag();
				stage.addEventListener(Event.ENTER_FRAME,updateHandler);
				stage.addEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
			}
			function stopDragHandler(ev:Event):void
			{
				s.stopDrag();
				slider.stopDrag();
				stage.removeEventListener(Event.ENTER_FRAME,updateHandler);
				stage.removeEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
			}
			s.addEventListener(MouseEvent.MOUSE_DOWN,startDragHandler);
		
			return s;
		}//endfunction
	}//endclass
}//endpackage

import flash.display.DisplayObject;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.events.FocusEvent;
import flash.geom.Point;
import flash.geom.Vector3D;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.filters.GlowFilter;
import flash.filters.DropShadowFilter;
import flash.text.TextFormat;
import flash.utils.getDefinitionByName;

class TopBarMenu extends Sprite
{
	private var Btns:Vector.<Sprite> = null;
	var callBackFn:Function = null;
		
	//===============================================================================================
	// 
	//===============================================================================================
	public function TopBarMenu(labels:XMLList,callBack:Function):void
	{
		callBackFn = callBack;
		
		// ----- create buttons
		Btns = new Vector.<Sprite>();
		var n:int = labels.length();
		for (var i:int=0; i<n; i++)
		{
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			var tff:TextFormat  = tf.defaultTextFormat;
			tff.font = "arial";
			tff.size = 14;
			tff.color = 0x888888;
			tf.defaultTextFormat = tff;
			tf.text = labels[i].@en;
			var b:Sprite = new Sprite();
			b.addChild(tf);
			b.buttonMode = true;
			b.mouseChildren = false;
			Btns.push(b);
			addChild(b);
		}
		
		// ----- draw btn bodies
		for (i=0; i<n; i++)
		{
			var btn:Sprite = Btns[i];
			var cW:int = btn.width;
			btn.graphics.beginFill(0xEEEEEE,1);
			btn.graphics.drawRoundRect(0,0,btn.width+10,btn.height,10,10);
			btn.graphics.endFill();
			btn.getChildAt(0).x=5;
		}
		
		// ----- aligning btns
		var offX:int=20;
		for (i=0; i<n; i++)
		{
			var c:DisplayObject = this.getChildAt(i);
			c.x = offX;
			c.y = 10;
			offX += c.width+20;
			var lin:Sprite = new Sprite();
			lin.graphics.lineStyle(0,0x888888);
			lin.graphics.lineTo(0,c.height);
			lin.x = offX-10;
			lin.y = c.y;
			addChild(lin);
		}
			
		var ppp:Sprite = this;
		function onAddedToStage(ev:Event):void
		{
			drawStripedRect(ppp,0,0,stage.stageWidth,ppp.height+20,0xFFFFFF,0xF6F6F6,0,10);
			ppp.filters = [new DropShadowFilter(4,90,0x000000,1,4,4,0.5)];
			ppp.removeEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
		}
		addEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
		addEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		addEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		addEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		addEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onMouseDown(ev:Event):void
	{
		if (stage==null) return;
		this.startDrag();
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onMouseUp(ev:Event):void
	{
		if (stage==null) return;
		this.stopDrag();
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				callBackFn(i);	// exec callback function
				return;
			}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onEnterFrame(ev:Event):void
	{
		if (stage==null) return;
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				if (Btns[i].filters==null)
					Btns[i].filters=[new GlowFilter(0x99AAFF,1,8,8,2)];
			}
			else
			{
				if (Btns[i].filters!=null)
				{
					var A:Array = Btns[i].filters;
					if (A.length>0 && (GlowFilter)(A[0]).strength>0)
						(GlowFilter)(A[0]).strength-=0.1;
					else 
						A = null;
					Btns[i].filters = A;
				}
			}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onRemove(ev:Event):void
	{
		removeEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		removeEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		removeEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		removeEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// draws a striped rectangle in given sprite 
	//===============================================================================================
	private static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
	{
		if (s==null)	s = new Sprite();
		var mat:Matrix = new Matrix();
		mat.createGradientBox(sw,sw,rot,0,0);
		s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
		s.graphics.drawRoundRect(x,y,w,h,rnd,rnd);
		s.graphics.endFill();
		
		return s;
	}//endfunction 
	
}//endfunction

class ButtonsMenu extends Sprite
{
	private var Btns:Vector.<Sprite> = null;
	private var Fns:Vector.<Function> = null;
	private var titleTf:TextField = null;

	//===============================================================================================
	// 
	//===============================================================================================
	public function ButtonsMenu(title:String,labels:Vector.<String>,callBacks:Vector.<Function>):void
	{
		Fns = callBacks;
		
		// ----- create title
		titleTf = new TextField();
		var tff:TextFormat = titleTf.defaultTextFormat;
		tff.font = "arial";
		tff.color = 0x888888;
		tff.bold = true;
		tff.size = 20;
		tff.align = "center";
		titleTf.defaultTextFormat = tff;
		titleTf.text = title;
		titleTf.autoSize = "left";
		titleTf.wordWrap = false;
		titleTf.selectable = false;
		addChild(titleTf);
		tff.size = 13;
		
		// ----- create buttons
		tff.size = 15;
		Btns = new Vector.<Sprite>();
		var n:int = Math.min(labels.length,callBacks.length);
		for (var i:int=0; i<n; i++)
		{
			var tf:TextField = new TextField();
			var itf:TextField  = null;
			tf.autoSize = "left";
			tf.wordWrap = false;
			tf.defaultTextFormat = tff;
			var lab:String = labels[i];
			if (lab.indexOf("[")!=-1 && lab.indexOf("]")!=-1)
			{
				var A:Array = lab.split("[");
				lab = A[0];
				itf = new TextField();
				itf.autoSize = "left";
				itf.wordWrap = false;
				itf.defaultTextFormat = tff;
				itf.text = A[1].split("]")[0];
				itf.border = true;
				itf.borderColor = 0x888888;
			}
			tf.text = lab;
			var b:Sprite = new Sprite();
			b.addChild(tf);
			if (itf!=null)
			{
				itf.x = tf.width;
				b.addChild(itf);
			}
			b.buttonMode = true;
			b.mouseChildren = false;
			Btns.push(b);
			addChild(b);
		}
		
		// ----- aligning
		var w:int = this.width;
		for (i=0; i<Btns.length; i++)
		{
			var btn:Sprite = Btns[i];
			var cW:int = btn.width;
			btn.graphics.beginFill(0xEEEEEE,1);
			btn.graphics.drawRoundRect(0,0,w,btn.height,10,10);
			btn.graphics.endFill();
			for (var j:int=0; j<btn.numChildren; j++)
				btn.getChildAt(j).x += (w-cW)/2;
		}
		var offY:int=20;
		for (i=0; i<this.numChildren; i++)
		{
			var c:DisplayObject = this.getChildAt(i);
			c.y = offY;
			c.x = w-c.width+10;
			offY += c.height+5;
		}
		drawStripedRect(this,0,0,w+20,this.height+40,0xFFFFFF,0xF6F6F6,20,10);
		
		this.filters = [new DropShadowFilter(4,45,0x000000,1,4,4,1)];
		
		addEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		addEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		addEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		addEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onMouseDown(ev:Event):void
	{
		if (stage==null) return;
		this.startDrag();
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onMouseUp(ev:Event):void
	{
		if (stage==null) return;
		this.stopDrag();
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				if (Btns[i].numChildren>1)
				{
					var itf:TextField = (TextField)(Btns[i].getChildAt(1));
					itf.type = "input";
					itf.background = true;
					if (stage.focus!=itf)
					{
						stage.focus = itf;
						function onFocusOut(ev:Event):void
						{
							Fns[i](itf.text);
							itf.removeEventListener(FocusEvent.FOCUS_OUT,onFocusOut);
						}
						itf.addEventListener(FocusEvent.FOCUS_OUT,onFocusOut);
					}
				}
				else
					Fns[i]();	// exec callback function
				return;
			}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onEnterFrame(ev:Event):void
	{
		if (stage==null) return;
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				if (Btns[i].filters==null)
					Btns[i].filters=[new GlowFilter(0x99AAFF,1,8,8,2)];
			}
			else
			{
				if (Btns[i].filters!=null)
				{
					var A:Array = Btns[i].filters;
					if (A.length>0 && (GlowFilter)(A[0]).strength>0)
						(GlowFilter)(A[0]).strength-=0.1;
					else 
						A = null;
					Btns[i].filters = A;
				}
			}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onRemove(ev:Event):void
	{
		removeEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		removeEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		removeEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		removeEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// draws a striped rectangle in given sprite 
	//===============================================================================================
	private static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
	{
		if (s==null)	s = new Sprite();
		var mat:Matrix = new Matrix();
		mat.createGradientBox(sw,sw,rot,0,0);
		s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
		s.graphics.drawRoundRect(x,y,w,h,10,10);
		s.graphics.endFill();
		
		return s;
	}//endfunction 
		
}//endclass

class AddFurnitureMenu extends Sprite
{
	private var Btns:Vector.<Sprite> = null;
	private var IcoCls:Vector.<Class> = null;
	private var floorPlan:FloorPlan = null;
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function AddFurnitureMenu(dat:XML,floorP:FloorPlan,icoW:int=50):void
	{
		Btns = new Vector.<Sprite>();
		IcoCls = new Vector.<Class>();
		floorPlan = floorP;
		
		for (var i:int=0; i<dat.item.length(); i++)
		{
			var btn:Sprite = new Sprite();
			btn.graphics.beginFill(0xFFFFFF,1);
			btn.graphics.drawRoundRect(0,0,icoW,icoW,icoW/10,icoW/10);
			btn.graphics.endFill();
			IcoCls.push(getDefinitionByName(dat.item[i].@cls));
			var ico:Sprite = new IcoCls[i]();
			var bnds:Rectangle = ico.getBounds(ico);
			var sc:Number = Math.min(icoW*0.8/ico.width,icoW*0.8/ico.height);
			ico.scaleX = ico.scaleY = sc;
			ico.x = (icoW-ico.width)/2 - bnds.left*sc;
			ico.y = (icoW-ico.height)/2 - bnds.top*sc;
			btn.addChild(ico);
			btn.buttonMode = true;
			btn.mouseChildren = false;
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			do {
				var tff:TextFormat = tf.defaultTextFormat;
				tff.color = 0x000000;
				tff.size = int(tff.size)-1;
				tf.defaultTextFormat = tff;
				tf.text = dat.item[i].@en;
			}
			while (tf.width>icoW);
			tf.y = btn.height;
			btn.addChild(tf);
			Btns.push(btn);
			btn.x = 10+(icoW+5)*(i%3);
			btn.y = 10+(icoW+20)*int(i/3);
			addChild(btn);
		}
		
		drawStripedRect(this,0,0,this.width+20,this.height+20,0xFFFFFF,0xF6F6F6,20);
		
		addEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		addEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		addEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		addEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onMouseDown(ev:Event):void
	{
		if (stage==null) return;
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onMouseUp(ev:Event):void
	{
		if (stage==null) return;
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				floorPlan.addFurniture(new IcoCls[i]());
				return;
			}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onEnterFrame(ev:Event):void
	{
		if (stage==null) return;
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				if (Btns[i].filters==null)
					Btns[i].filters=[new GlowFilter(0x99AAFF,1,8,8,2)];
			}
			else
			{
				if (Btns[i].filters!=null)
				{
					var A:Array = Btns[i].filters;
					if (A.length>0 && (GlowFilter)(A[0]).strength>0)
						(GlowFilter)(A[0]).strength-=0.1;
					else 
						A = null;
					Btns[i].filters = A;
				}
			}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	private function onRemove(ev:Event):void
	{
		removeEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		removeEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		removeEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		removeEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// draws a striped rectangle in given sprite 
	//===============================================================================================
	private static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
	{
		if (s==null)	s = new Sprite();
		var mat:Matrix = new Matrix();
		mat.createGradientBox(sw,sw,rot,0,0);
		s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
		s.graphics.drawRoundRect(x,y,w,h,10,10);
		s.graphics.endFill();
		
		return s;
	}//endfunction
}//endclass

class WireGrid extends Sprite
{
	public var sw:int = 800;
	public var sh:int = 600;
	
	//=============================================================================================
	// constructor for background grid markings sprite
	//=============================================================================================
	public function WireGrid(w:int,h:int):void
	{
		sw = w;
		sh = h;
		update();
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	public function zoom(sc:Number):void
	{
		// ----- shift so that zoom is in center
		var ompt:Point = new Point((-x+sw/2)/scaleX,(-y+sh/2)/scaleY);	// original middle point
		var nmpt:Point = new Point((-x+sw/2)/sc,(-y+sh/2)/sc);			// new skewed middle point
		var dv:Point = ompt.subtract(nmpt);
		x-= dv.x*sc;
		y-= dv.y*sc;
		
		scaleX = scaleY = sc;
		update();
	}//endfunction
	
	//=============================================================================================
	// redraws the grid background so the grid lines always cover the screen
	//=============================================================================================
	public function update():void
	{
		var interval:int = 10;
		var rect:Rectangle = new Rectangle(-x/scaleX,-y/scaleY,sw/scaleX,sh/scaleY);	// define rectangle to draw
		
		// ----- draw bg color
		graphics.clear();
		graphics.beginFill(0xEEEEF3,1);
		graphics.drawRect(rect.x,rect.y,rect.width,rect.height);
		graphics.endFill();
		
		// ----- draw grid lines
		var i:int = 0;
		var a:int = int(rect.left/interval)*interval;
		for (i=a; i<=rect.right; i+=interval)	
		{
			if (i%(interval*10)==0)	graphics.lineStyle(0, 0xCCCCCC, 1);
			else					graphics.lineStyle(0, 0xE5E5E5, 1);
			graphics.moveTo(i,rect.top);
			graphics.lineTo(i,rect.bottom);
		}
		a = int(rect.top/interval)*interval;
		for (i=a; i<=rect.bottom; i+=interval)	
		{
			if (i%(interval*10)==0)	graphics.lineStyle(0, 0xCCCCCC, 1);
			else					graphics.lineStyle(0, 0xE5E5E5, 1);
			graphics.moveTo(rect.left,i);
			graphics.lineTo(rect.right,i);
		}
	}//endfunction
	
}//endclass

class FloorPlan
{
	public var Joints:Vector.<Point>;
	public var Walls:Vector.<Wall>;
	public var Furniture:Vector.<Sprite>;		// list of furniture sprite already on the stage
	public var floorAreas:Vector.<Sprite>;		// list of floor area sprites already on the stage
	
	public var selected:* = null;				// of Furniture or Joint or Wall
	
	private var jointsOverlay:Sprite = null;	// to draw all the joint positions in
	public var overlay:Sprite = null;			// to add to display list
	
	//=============================================================================================
	//
	//=============================================================================================
	public function FloorPlan():void
	{
		Joints = new Vector.<Point>();
		Walls = new Vector.<Wall>();
		
		Furniture = new Vector.<Sprite>();
		floorAreas = new Vector.<Sprite>();
		
		jointsOverlay = new Sprite();
		overlay = new Sprite();
		overlay.buttonMode = true;
	}//endfunction
	
	//=============================================================================================
	// covert data to JSON formatted string
	//=============================================================================================
	public function exportData():String
	{
		var o:Object = new Object();
		o.Joints = Joints;
		o.Walls = Walls;
		
		function replacer(k,v):*
		{
			if (v is Wall)			// joints become indexes
			{
				var wo:Object = new Object();
				wo.j1 = Joints.indexOf((Wall)(v).joint1);
				wo.j2 = Joints.indexOf((Wall)(v).joint2);
				wo.w = (Wall)(v).thickness;
				wo.Doors = (Wall)(v).Doors;
				return wo;
			}
			else if(v is Point)		// so only x,y vals are converted
			{
				var po:Object = new Object();
				po.x = v.x;
				po.y = v.y;
				return po;
			}
			
			return v;
		}
		return JSON.stringify(o,replacer);
	}//endfunction
	
	//=============================================================================================
	// converts from JSON data back to floorPlan, original data will be OVERRIDDEN
	//=============================================================================================
	public function importData(dat:String):void
	{
		var o:Object = JSON.parse(dat);
		
		// ----- replace joints
		Joints = new Vector.<Point>();
		for (var i:int=o.Joints.length-1; i>-1; i--)
		{
			var po:Object = o.Joints[i];
			Joints.unshift(new Point(po.x,po.y));
		}
		
		// ----- replace walls
		while (Walls.length>0)					// clear off prev walls
			overlay.removeChild(Walls.pop());
		for (i=o.Walls.length-1; i>-1; i--)		// add in new walls
		{
			var wo:Object = o.Walls[i];
			var wall:Wall = new Wall(Joints[wo.j1],Joints[wo.j2],wo.w);
			for (var j:int=wo.Doors.length-1; j>-1; j--)
			{
				var d:Object = wo.Doors[j];
				var door:Door = new Door(Number(d.piv),Number(d.dir));
				door.angL = Number(d.angL);
				door.angR = Number(d.angR);
				door.thickness = d.thickness;
				wall.Doors.unshift(door);
			}
			overlay.addChild(wall);
			Walls.unshift(wall);
		}
		
		refresh();
	}//endfunction
	
	//=============================================================================================
	// creates and add wall to floorplan 
	//=============================================================================================
	public function createWall(pt1:Point, pt2:Point, width:Number=10, snapDist:Number=10):Wall
	{
		// ----- snap pt1 to existing joint
		var nearest:Point = null;
		for (var i:int=Joints.length-1; i>-1;i--)
			if (nearest==null || Joints[i].subtract(pt1).length<nearest.subtract(pt1).length)
				nearest=Joints[i];
		if (nearest!=null && nearest.subtract(pt1).length<snapDist)	
			pt1 = nearest;
		else
			Joints.push(pt1);
		
		// ----- snap pt2 to existing joint not pt1
		nearest = null;
		for (i=Joints.length-1; i>-1; i--)
			if (Joints[i]!=pt1)
			{
				if (nearest==null || Joints[i].subtract(pt2).length<nearest.subtract(pt2).length)
					nearest=Joints[i];
			}
		if (nearest!=null && nearest.subtract(pt2).length<snapDist)	
			pt2 = nearest;
		else
			Joints.push(pt2);
		
		// ----- register new wall
		var wall:Wall = new Wall(pt1, pt2, width);
		Walls.push(wall);
		drawWall(wall);
		overlay.addChild(wall);
		return wall;
	}//endfunction
	
	//=============================================================================================
	//
	//=============================================================================================
	public function removeWall(wall:Wall):void
	{
		if (Walls.indexOf(wall)!=-1)	Walls.splice(Walls.indexOf(wall),1);
		if (wall.parent!=null)			wall.parent.removeChild(wall);	
		
		var canRemJt1:Boolean = true;
		var canRemJt2:Boolean = true;
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var w:Wall = Walls[i];
			if (w.joint1==wall.joint1 || w.joint2==wall.joint1)	canRemJt1 = false;
			if (w.joint1==wall.joint2 || w.joint2==wall.joint2)	canRemJt2 = false;
		}
		if (canRemJt1 && Joints.indexOf(wall.joint1)!=-1) Joints.splice(Joints.indexOf(wall.joint1),1);
		if (canRemJt2 && Joints.indexOf(wall.joint2)!=-1) Joints.splice(Joints.indexOf(wall.joint2),1);
	}//endfunction
	
	//=============================================================================================
	// finds the nearest joint to this position
	//=============================================================================================
	public function nearestJoint(posn:Point,cutOff:Number):Point
	{
		var joint:Point = null;
		for (var i:int=Joints.length-1; i>-1; i--)
			if (Joints[i]!=posn && cutOff>Joints[i].subtract(posn).length)
			{
				joint = Joints[i];
				cutOff = joint.subtract(posn).length;
			}
		return joint;
	}//endfunction
	
	//=============================================================================================
	//
	//=============================================================================================
	public function replaceJointWith(jt:Point,njt:Point):void
	{
		if (Joints.indexOf(jt)==-1)	Joints.push(njt);
		else						Joints[Joints.indexOf(jt)]=njt;
		
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			if (Walls[i].joint1==jt)	Walls[i].joint1=njt;
			if (Walls[i].joint2==jt)	Walls[i].joint2=njt;
			if (Walls[i].joint1==Walls[i].joint2)
			{	// remove any 0 lengthwall
				overlay.removeChild(Walls[i]);
				Walls.splice(i,1);
			}
		}
	}//endfunction
	
	//=============================================================================================
	// finds the nearest wall to this position
	//=============================================================================================
	public function nearestWall(posn:Point,cutOff:Number):Wall
	{
		var wall:Wall = null;
		for (var i:int=Walls.length-1; i>-1; i--)
			if (cutOff > Walls[i].perpenticularDist(posn))
			{
				wall = Walls[i];
				cutOff = wall.perpenticularDist(posn);
			}
		return wall;
	}//endfunction
	
	//=============================================================================================
	// returns wall that collided with given wall or null 
	//=============================================================================================
	public function chkWallCollide(wall:Wall):Wall
	{
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var w:Wall = Walls[i];
			if (segmentsIntersectPt(w.joint1.x,w.joint1.y,w.joint2.x,w.joint2.y, wall.joint1.x,wall.joint1.y,wall.joint2.x,wall.joint2.y)!=null)
				return w;
		}
		
		return null;
	}//endfunction
	
	//=============================================================================================
	// find position of point projected onto wall
	//=============================================================================================
	public function projectedWallPosition(wall:Wall, pt:Point) : Point
	{
		var vpt:Point = pt.subtract(wall.joint1);
		var dir:Point = wall.joint2.subtract(wall.joint1);
		dir.normalize(1);
		var k:Number =dir.x*vpt.x + dir.y*vpt.y;
		
		return new Point(wall.joint1.x + dir.x*k, wall.joint1.y + dir.y * k);;
	}//endfunction
	
	//=============================================================================================
	// redraws every wall
	//=============================================================================================
	public function refresh():void
	{
		// ----- redraw all walls ---------------------------------------------
		var i:int=0;
		for (i=Walls.length-1; i>-1; i--)
			drawWall(Walls[i]);
		
		// ----- redraw enclosed floor areas ----------------------------------
		var A:Vector.<Vector.<Point>> = findIsolatedAreas();
		while (floorAreas.length<A.length) 
		{
			var s:Sprite = new Sprite();
			floorAreas.push(s);
			overlay.addChildAt(s,0);
		}
		while (floorAreas.length>A.length)
			overlay.removeChild(floorAreas.pop());
		for (i=A.length-1; i>-1; i--)	// draw for each floorArea
			drawFloorArea(A[i],new BitmapData(1,1,false,0xDDEEEE),floorAreas[i]);
		
		// ----- redraw wall joint positions ----------------------------------
		jointsOverlay.graphics.clear();
		jointsOverlay.graphics.lineStyle(2,0x666666,1);
		for (i=Joints.length-1; i>-1; i--)
		{
			if (selected==Joints[i])
				jointsOverlay.graphics.beginFill(0xFF6600,1);
			else
				jointsOverlay.graphics.beginFill(0xE9E9E9,1);
			jointsOverlay.graphics.drawCircle(Joints[i].x,Joints[i].y,3);
			jointsOverlay.graphics.endFill();
		}
		if (jointsOverlay.parent!=null)
			jointsOverlay.parent.removeChild(jointsOverlay);
		overlay.addChild(jointsOverlay);
	}//endfunction
	
	//=============================================================================================
	// draws wall with any door and windows on it
	//=============================================================================================
	public function drawWall(wall:Wall):void
	{
		// ----- draw wall bounds
		var wallB:Vector.<Point> = wall.wallBounds(false);
				
		var ipt:Point = null;
		var j:int=0;
		var wb:Vector.<Point>=null;
		var Adj:Vector.<Wall> = connectedToJoint(wall.joint2);
		for (j=Adj.length-1; j>-1; j--)
		{
			wb = null;
			if (Adj[j].joint2==wall.joint2)		wb = Adj[j].wallBounds(true);	// ensure point ordering is correct
			else								wb = Adj[j].wallBounds(false);
			
			ipt = extendedSegsIntersectPt(wallB[0].x,wallB[0].y,wallB[1].x,wallB[1].y,wb[0].x,wb[0].y,wb[1].x,wb[1].y);
			if (ipt!=null)	wallB[1] = ipt;
			ipt = extendedSegsIntersectPt(wallB[3].x,wallB[3].y,wallB[2].x,wallB[2].y,wb[3].x,wb[3].y,wb[2].x,wb[2].y);
			if (ipt!=null)	wallB[2] = ipt;
		}
		
		Adj = connectedToJoint(wall.joint1);
		for (j=Adj.length-1; j>-1; j--)
		{
			wb = null;
			if (Adj[j].joint2==wall.joint1)		wb = Adj[j].wallBounds(false);	// ensure point ordering is correct
			else								wb = Adj[j].wallBounds(true);
			
			ipt = extendedSegsIntersectPt(wallB[0].x,wallB[0].y,wallB[1].x,wallB[1].y,wb[0].x,wb[0].y,wb[1].x,wb[1].y);
			if (ipt!=null)	wallB[0] = ipt;
			ipt = extendedSegsIntersectPt(wallB[3].x,wallB[3].y,wallB[2].x,wallB[2].y,wb[3].x,wb[3].y,wb[2].x,wb[2].y);
			if (ipt!=null)	wallB[3] = ipt;
		}
		// ----- draws the calculated wallB
		wall.graphics.clear();
		while (wall.numChildren>0)	wall.removeChildAt(0);
		if (selected==wall)		wall.graphics.beginFill(0xFF6600,1);
		else					wall.graphics.beginFill(0x000000,1);
		wall.graphics.moveTo(wallB[0].x,wallB[0].y);
		wall.graphics.lineTo(wallB[1].x,wallB[1].y);
		wall.graphics.lineTo(wallB[2].x,wallB[2].y);
		wall.graphics.lineTo(wallB[3].x,wallB[3].y);
		wall.graphics.lineTo(wallB[0].x,wallB[0].y);
		wall.graphics.endFill();
		
		// ----- draw wall length info
		var ux:Number = wallB[1].x-wallB[0].x;
		var uy:Number = wallB[1].y-wallB[0].y;
		var vl:Number = Math.sqrt(ux*ux+uy*uy);
		ux/=vl; uy/=vl;
		drawI(wall,wallB[0].x+uy*5,wallB[0].y-ux*5,wallB[1].x+uy*5,wallB[1].y-ux*5,10,true);
		drawI(wall,wallB[2].x-uy*5,wallB[2].y+ux*5,wallB[3].x-uy*5,wallB[3].y+ux*5,10,true);
		
		// ----- draw all doors
		for (j=wall.Doors.length-1; j>-1; j--)
		{
			var door:Door = wall.Doors[j];
			var piv:Point = new Point(	wall.joint1.x + (wall.joint2.x-wall.joint1.x)*door.pivot,
										wall.joint1.y + (wall.joint2.y-wall.joint1.y)*door.pivot);
			var dir:Point = new Point(	(wall.joint2.x-wall.joint1.x)*door.dir,
										(wall.joint2.y-wall.joint1.y)*door.dir);
			var bearing:Number = Math.atan2(dir.x,-dir.y);
			var angL:Number = bearing+door.angL;
			var angR:Number = bearing+door.angR;
			wall.graphics.lineStyle(0,0x000000,1);
			var cnt:int = 0;
			wall.graphics.moveTo(piv.x,piv.y);
			for (var deg:Number=angL; deg<angR; deg+=Math.PI/32)
			{
				if (cnt%2==0)
					wall.graphics.lineTo(piv.x+Math.sin(deg)*dir.length,piv.y-Math.cos(deg)*dir.length);
				else
					wall.graphics.moveTo(piv.x+Math.sin(deg)*dir.length,piv.y-Math.cos(deg)*dir.length);
				cnt++;
			}
			drawBar(wall,piv,piv.add(new Point(Math.sin(angL)*dir.length,-Math.cos(angL)*dir.length)),door.thickness);
			drawBar(wall,piv,piv.add(new Point(Math.sin(angR)*dir.length,-Math.cos(angR)*dir.length)),door.thickness);
		}
	}//endfunction
	
	//=============================================================================================
	// adds a furniture icon to floorplan
	//=============================================================================================
	public function addFurniture(fu:Sprite):void
	{
		Furniture.push(fu);
		overlay.addChild(fu);
		
		// ----- hack to start dragging
		if (overlay.stage!=null)
		{
			function enterFrameHandler(ev:Event=null) :void
			{
				fu.x = overlay.mouseX;
				fu.y = overlay.mouseY;
			}
			function mouseDownHandler(ev:Event=null):void
			{
				fu.removeEventListener(Event.ENTER_FRAME,enterFrameHandler);
				overlay.stage.removeEventListener(MouseEvent.MOUSE_UP,mouseDownHandler);	
			}
			fu.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
			overlay.stage.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		}
	}//endfunction
	
	//=============================================================================================
	// selects and returns the Joint/Wall/Furniture selected under current mouse position, or null
	//=============================================================================================
	private var furnitureCtrls:Sprite = null;
	public function mouseSelect():*
	{
		if (furnitureCtrls!=null)
		{
			if (furnitureCtrls.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY)) 
				return selected;
			furnitureCtrls.parent.removeChild(furnitureCtrls);		// clear off furniture transform controls
			furnitureCtrls = null;
		}
		
		selected = null;	// clear prev selected
		
		for (var i:int=Furniture.length-1; i>-1; i--)
			if (Furniture[i].hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY))	// chk if on furniture
				selected = Furniture[i];
		
		if (selected!=null)
		{
			furnitureCtrls = furnitureTransformControls(selected);
			overlay.addChild(furnitureCtrls);
		}
		
		if (selected==null)
			selected = nearestJoint(new Point(overlay.mouseX,overlay.mouseY), 10);		// chk if near any joint
		
		if (selected==null)
			selected = nearestWall(new Point(overlay.mouseX,overlay.mouseY), 10);		// chk if near any wall
		
	}//endfunction
		
	//=============================================================================================
	// add controls to target furniture to shift scale rotate furniture
	//=============================================================================================
	public function furnitureTransformControls(targ:Sprite,marg:int=5):Sprite
	{
		var ctrls:Sprite = new Sprite();
		
		function drawCtrls():void
		{
			var rot:Number = targ.rotation;
			var bnds:Rectangle = targ.getBounds(targ);
			bnds.x *= targ.scaleX;
			bnds.width *= targ.scaleX;
			bnds.y *= targ.scaleY;
			bnds.height *= targ.scaleY;
			while (ctrls.numChildren>0)	ctrls.removeChildAt(0);
			ctrls.graphics.clear();
			drawI(ctrls,bnds.left-marg,bnds.top,bnds.left-marg,bnds.bottom,marg*2,true);
			drawI(ctrls,bnds.left,bnds.top-marg,bnds.right,bnds.top-marg,marg*2,true);
			drawI(ctrls,bnds.right+marg,bnds.top,bnds.right+marg,bnds.bottom,marg*2);
			drawI(ctrls,bnds.left,bnds.bottom+marg,bnds.right,bnds.bottom+marg,marg*2);
			drawI(ctrls,bnds.left,bnds.top,bnds.right,bnds.bottom,marg*2,true);
			ctrls.graphics.beginFill(0x666666,1);
			ctrls.graphics.drawCircle(bnds.left-marg,bnds.top-marg,marg-1);
			ctrls.graphics.drawCircle(bnds.right+marg,bnds.bottom+marg,marg-1);
			ctrls.graphics.endFill();
			ctrls.x = targ.x;
			ctrls.y = targ.y;
			ctrls.rotation = targ.rotation;
			ctrls.buttonMode = true;
		}
		drawCtrls();
		
		var mouseDownPt:Point=null;
		var mode:String = "";
		var oPosn:Vector3D = null;	// {x,y,0,rotation}
		var oScale:Point = null;
		function enterFrameHandler(ev:Event) : void
		{
			if (mode=="drag")
			{
				targ.x = oPosn.x+ctrls.parent.mouseX-mouseDownPt.x;
				targ.y = oPosn.y+ctrls.parent.mouseY-mouseDownPt.y;
			}
			else if (mode=="rotate")
			{
				var pvx:Number = mouseDownPt.x-oPosn.x;
				var pvy:Number = mouseDownPt.y-oPosn.y;
				var pvl:Number = Math.sqrt(pvx*pvx+pvy*pvy);
				pvx/=pvl; pvy/=pvl;
				
				var qvx:Number = ctrls.parent.mouseX-oPosn.x;
				var qvy:Number = ctrls.parent.mouseY-oPosn.y;
				var qvl:Number = Math.sqrt(qvx*qvx+qvy*qvy);
				qvx/=qvl; qvy/=qvl;
				var angDiff:Number = Math.acos(pvx*qvx+pvy*qvy);
				if (pvx*qvy-pvy*qvx<0)	angDiff*=-1;
				targ.rotation = oPosn.w+angDiff/Math.PI*180;
			}
			else if (mode=="scaleX" || mode=="scaleY")
			{
				var opt:Point = mouseDownPt.subtract(new Point(ctrls.x,ctrls.y));
				var mpt:Point = new Point(ctrls.parent.mouseX-ctrls.x,ctrls.parent.mouseY-ctrls.y);
				var sc:Number = mpt.length/opt.length;
				if (mode=="scaleX")	targ.scaleX = oScale.x*sc;
				if (mode=="scaleY")	targ.scaleY = oScale.y*sc;
				drawCtrls();
			}
					
			ctrls.rotation = targ.rotation;
			ctrls.x = targ.x;
			ctrls.y = targ.y;
		}//endfunction
		
		function mouseDownHandler(ev:Event):void
		{
			mouseDownPt = new Point(ctrls.parent.mouseX,ctrls.parent.mouseY);
			oPosn = new Vector3D(targ.x,targ.y,0,targ.rotation);
			oScale = new Point(targ.scaleX,targ.scaleY);
			var bnds:Rectangle = targ.getBounds(targ);
			bnds.x *= targ.scaleX;
			bnds.width *= targ.scaleX;
			bnds.y *= targ.scaleY;
			bnds.height *= targ.scaleY;
			if (ctrls.mouseX>bnds.left && ctrls.mouseX<bnds.right &&
				ctrls.mouseY>bnds.top && ctrls.mouseY<bnds.bottom)
				mode = "drag";
			else if (ctrls.mouseX>bnds.left && ctrls.mouseX<bnds.right)
				mode = "scaleY";
			else if (ctrls.mouseY>bnds.top && ctrls.mouseY<bnds.bottom)
				mode = "scaleX";
			else
				mode = "rotate";
		}//endfunction
		
		function mouseUpHandler(ev:Event):void
		{
			mode = "";
		}//endfunction
		
		function removeHandler(ev:Event):void
		{
			ctrls.removeEventListener(Event.REMOVED_FROM_STAGE,removeHandler);
			ctrls.removeEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
			ctrls.removeEventListener(Event.ENTER_FRAME,enterFrameHandler);
			overlay.stage.removeEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
		}
		
		ctrls.addEventListener(Event.REMOVED_FROM_STAGE,removeHandler);
		ctrls.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		ctrls.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
		overlay.stage.addEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
		
		return ctrls;
	}

	//=============================================================================================
	// convenience function to draw the length markings
	//=============================================================================================
	private function drawI(s:Sprite,ax:Number,ay:Number,bx:Number,by:Number,w:int=6,showLen:Boolean=false):void
	{
		var vx:Number = bx-ax;
		var vy:Number = by-ay;
		var vl:Number = Math.sqrt(vx*vx+vy*vy);
		var ux:Number = vx/vl;
		var uy:Number = vy/vl;
		w/=2;
		// ----- draw rect
		s.graphics.lineStyle();
		s.graphics.beginFill(0x000000,0);
		s.graphics.moveTo(ax-uy*w,ay+ux*w);
		s.graphics.lineTo(ax+uy*w,ay-ux*w);
		s.graphics.lineTo(bx+uy*w,by-ux*w);	
		s.graphics.lineTo(bx-uy*w,by+ux*w);
		s.graphics.endFill();
		
		// ----- draw lines
		s.graphics.lineStyle(0,0x666666,1);
		s.graphics.moveTo(ax-uy*w,ay+ux*w);
		s.graphics.lineTo(ax+uy*w,ay-ux*w);
		s.graphics.moveTo(bx-uy*w,by+ux*w);
		s.graphics.lineTo(bx+uy*w,by-ux*w);	
		
		if (showLen)
		{
			var tf:TextField = new TextField();
			var tff:TextFormat = tf.defaultTextFormat;
			tff.color = 0x000000;
			tff.font = "arial";
			tf.wordWrap = false;
			tf.autoSize = "left";
			tf.selectable = false;
			tf.text = (int(vl)/100)+"m";
			var bmp:Bitmap = new Bitmap(new BitmapData(tf.width,tf.height,true,0x00000000),"auto",true);
			bmp.bitmapData.draw(tf,null,null,null,null,true);
			var rot:Number = Math.atan2(ux,-uy)-Math.PI/2;
			var tx:Number = -0.5*bmp.width;
			var ty:Number = 0.5*bmp.height;
			bmp.x = tx*Math.cos(rot)+ty*Math.sin(rot);
			bmp.y = -(ty*Math.cos(rot)-tx*Math.sin(rot));
			bmp.rotation = rot/Math.PI*180;
			bmp.x += (ax+bx)/2;
			bmp.y += (ay+by)/2;
			s.addChild(bmp);
			var tw:int = Math.max(bmp.width,bmp.height);
			s.graphics.moveTo(ax,ay);
			s.graphics.lineTo(ax+ux*(vl-tw)/2,ay+uy*(vl-tw)/2);
			s.graphics.moveTo(bx,by);
			s.graphics.lineTo(bx-ux*(vl-tw)/2,by-uy*(vl-tw)/2);
		}
		else
		{
			s.graphics.moveTo(ax,ay);
			s.graphics.lineTo(bx,by);
		}
	}//endfunction
	
	//=============================================================================================
	// convenience function to extend wall ends so they intersect nicely at acute angles
	//=============================================================================================
	private function extendedSegsIntersectPt(ax:Number,ay:Number,bx:Number,by:Number,cx:Number,cy:Number,dx:Number,dy:Number,ext:Number=100):Point
	{
		var pvx:Number = bx-ax;
		var pvy:Number = by-ay;
		var pvl:Number = Math.sqrt(pvx*pvx+pvy*pvy);
		pvx*=ext/pvl; pvy*=ext/pvl;
		var qvx:Number = dx-cx;
		var qvy:Number = dy-cy;
		var qvl:Number = Math.sqrt(qvx*qvx+qvy*qvy);
		qvx*=ext/qvl; qvy*=ext/qvl;
		return segmentsIntersectPt(ax-pvx,ay-pvy,bx+pvx,by+pvy,cx-qvx,cy-qvy,dx+qvx,dy+qvy);
	}//endfunction
	
	//=============================================================================================
	// draws a generic rectangle in given sprite s
	//=============================================================================================
	private function drawBar(s:Sprite,from:Point,to:Point,thickness:Number):void
	{
		var dir:Point = to.subtract(from);
		var dv:Point = new Point(dir.x/dir.length*thickness/2,dir.y/dir.length*thickness/2);
		s.graphics.beginFill(0xCCCCCC,1);
		s.graphics.moveTo(from.x-dv.y,from.y+dv.x);
		s.graphics.lineTo(from.x+dv.y,from.y-dv.x);
		s.graphics.lineTo(to.x+dv.y,to.y-dv.x);
		s.graphics.lineTo(to.x-dv.y,to.y+dv.x);
		s.graphics.endFill();
	}//endfunction
	
	//=============================================================================================
	// finds all walls connected to given wall joint
	//=============================================================================================
	private function connectedToJoint(pt:Point):Vector.<Wall>
	{
		var W:Vector.<Wall> = new Vector.<Wall>();
		for (var i:int=Walls.length-1; i>-1; i--)
			if (Walls[i].joint1==pt || Walls[i].joint2==pt)
				W.push(Walls[i]);
		return W;
	}//endfunction
	
	//=============================================================================================
	// draws the given floor area poly with calculated area in m sq
	//=============================================================================================
	public function drawFloorArea(poly:Vector.<Point>,bmd:BitmapData,s:Sprite=null):Sprite
	{
		if (poly==null || poly.length==0)	return null;
		
		if (s==null) s = new Sprite();
		else 		s.graphics.clear();
		
		s.graphics.lineStyle(0,0x000000,1);
		s.graphics.beginBitmapFill(bmd);
		var i:int=poly.length-1;
		s.graphics.moveTo(poly[i].x,poly[i].y);
		for (; i>-1; i--)
			s.graphics.lineTo(poly[i].x,poly[i].y);
		i=poly.length-1;
		s.graphics.lineTo(poly[i].x,poly[i].y);
		s.graphics.endFill();
		
		var bnds:Rectangle = s.getBounds(s);
		var tf:TextField = null;
		if (s.numChildren>0 && s.getChildAt(0) is TextField) 	
			tf = (TextField)(s.getChildAt(0));
		else
		{
			tf = new TextField();
			var tff:TextFormat = tf.defaultTextFormat;
			tff.color = 0x999999;
			tf.defaultTextFormat = tff;
			tf.autoSize = "left";
			tf.wordWrap = false;
			tf.selectable = false;
			s.addChild(tf);
		}
		tf.text = int(calculateArea(poly)/100)/100+"m sq.";
		tf.x = bnds.left+(bnds.width-tf.width)/2;
		tf.y = bnds.top+(bnds.height-tf.height)/2;
				
		return s;
	}//endfunction
	
	//=============================================================================================
	// find cyclics, i.e. room floor areas
	//=============================================================================================
	public function findIsolatedAreas():Vector.<Vector.<Point>>
	{
		var R:Vector.<Vector.<Point>> = new Vector.<Vector.<Point>>();	// results
		
		//-------------------------------------------------------------------------------
		function seek(curJoint:Point,path:Vector.<Point>) : void
		{
			if (path.indexOf(curJoint)!=-1)
			{
				var loop:Vector.<Point> = path.slice(path.indexOf(curJoint));
				if (loop.length>2)
				{	
					// binary insert longest loop at n shortest at 0
					var p:int = 0;
					var q:int = R.length-1;
					while (p<=q)
					{
						var m:int = (p+q)/2;
						if (R[m].length<loop.length)
							p=m+1;
						else
							q=m-1;
					}
					R.splice(p,0,loop);	// insert at posn
				}
			}
			else
			{
				// walk all edges
				var edges:Vector.<Wall> = connectedToJoint(curJoint);
				path = path.slice();	// duplicate
				path.push(curJoint);
				for (var i:int=0; i<edges.length; i++)
				{
					if (edges[i].joint1==curJoint)	
						seek(edges[i].joint2,path);
					else
						seek(edges[i].joint1,path);
				}
			}
		}//endfunction
		
		seek(Joints[0],new Vector.<Point>());
		
		// ----- extract only the shortest
		var Visited:Vector.<Point> = new Vector.<Point>();
		var Rp:Vector.<Vector.<Point>> = new Vector.<Vector.<Point>>();
		while (R.length>0)
		{
			var isNew:Boolean = false;
			var loop:Vector.<Point> = R.shift();
			for (var i:int=loop.length-1; i>-1; i--)
				if (Visited.indexOf(loop[i])==-1)
				{
					Visited.push(loop[i]);
					isNew = true;
				}
			
			if (isNew)
			{
				var lp:Vector.<Point> = new Vector.<Point>();
				for (i=loop.length-1; i>-1; i--)
					lp.unshift(new Point(loop[i].x,loop[i].y));
				Rp.push(lp);
			}
		}
		
		return Rp;
	}//endfunction
	
	//=======================================================================================
	// calculates area of poly by triangulating and summing the triangle areas
	//=======================================================================================
	public static function calculateArea(Poly:Vector.<Point>):Number
	{
		var area:Number = 0;
		var Tris:Vector.<Point> = triangulate(Poly);
		var n:int = Tris.length;
		for (var i:int=0; i<n; i+=3)
		{
			var bux:Number = Tris[i+1].x-Tris[i].x;
			var buy:Number = Tris[i+1].y-Tris[i].y;
			var bvl:Number = Math.sqrt(bux*bux+buy*buy);
			bux/=bvl; buy/=bvl;
			
			var qx:Number = Tris[i+2].x-Tris[i].x;
			var qy:Number = Tris[i+2].y-Tris[i].y;
			var ql:Number = Math.sqrt(qx*qx+qy*qy);
			var proj:Number = qx*bux + qy*buy;
			var normD:Number = Math.sqrt(ql*ql-proj*proj);
			
			area += 0.5*normD*bvl;
		}
		
		return area;
	}//endfunction

	//=======================================================================================
	// triangulate by cutting ears off polygon O(n*n)  slow... just so i can find floorarea
	//=======================================================================================
	public static function triangulate(Poly:Vector.<Point>):Vector.<Point>
	{
		var R:Vector.<Point> = new Vector.<Point>();
		var P:Vector.<Point> = Poly.slice();
		
		while (P.length>3)
		{
			do {
				P.push(P.shift());
			} while (!edgeInPoly(P[0].x,P[0].y,P[2].x,P[2].y,P));	// chk cut line is actually in poly
			R.push(P[0],P[1],P[2]);	// push triangle in result
			P.splice(1,1);			// remove P[1]
		}
		
		return R;
	}//endfunction

	//=======================================================================================
	// test if edge connecting 2 points is entirely in poly
	//=======================================================================================
	public static function edgeInPoly(ax:Number,ay:Number,bx:Number,by:Number,Poly:Vector.<Point>):Boolean
	{
		var n:int = Poly.length;
		for (var i:int=n-1; i>0; i--)
			if (segmentsIntersectPt(Poly[i].x,Poly[i].y,Poly[i-1].x,Poly[i-1].y,ax,ay,bx,by))
				return false;
		if (segmentsIntersectPt(Poly[0].x,Poly[0].y,Poly[n-1].x,Poly[n-1].y,ax,ay,bx,by))
			return false;
		
		return pointInPoly(new Point((ax+bx)/2,(ay+by)/2),Poly);
	}//endfunction

	//=======================================================================================
	// tests if pt is within polygon
	//=======================================================================================
	public static function pointInPoly(pt:Point,Poly:Vector.<Point>):Boolean
	{
		// ----- find external point (top left)
		var n:int = Poly.length;
		var extPt:Point = new Point(0,0);
		for (var i:int=n-1; i>-1; i--)
		{
			if (Poly[i].x<extPt.x)	extPt.x = Poly[i].x;
			if (Poly[i].y<extPt.y)	extPt.y = Poly[i].y;
		}
		extPt.x-=1;
		extPt.y-=1;
		
		var cnt:int=0;	// count number of intersects
		for (i=n-1; i>0; i--)
			if (segmentsIntersectPt(Poly[i].x,Poly[i].y,Poly[i-1].x,Poly[i-1].y,extPt.x,extPt.y,pt.x,pt.y))
				cnt++;
		if (segmentsIntersectPt(Poly[0].x,Poly[0].y,Poly[n-1].x,Poly[n-1].y,extPt.x,extPt.y,pt.x,pt.y))
			cnt++;
		
		return (cnt%2)==1;
	}//endfunction

	//=======================================================================================
	// find line segments intersect point of lines A=(ax,ay,bx,by) C=(cx,cy,dx,dy)
	// returns null for parrallel segs and point segments, does not detect end points
	//=======================================================================================
	public static function segmentsIntersectPt(ax:Number,ay:Number,bx:Number,by:Number,cx:Number,cy:Number,dx:Number,dy:Number) : Point
	{
		if ((ax==cx && ay==cy) || (ax==dx && ay==dy)) return null;	// false if any endpoints are shared
		if ((bx==cx && by==cy) || (bx==dx && by==dy)) return null;
			
		var avx:Number = bx-ax;
		var avy:Number = by-ay;
		var cvx:Number = dx-cx;
		var cvy:Number = dy-cy;
				
		var al:Number = Math.sqrt(avx*avx + avy*avy);	// length of seg A
		var cl:Number = Math.sqrt(cvx*cvx + cvy*cvy);	// length of seg C
		
		if (al==0 || cl==0 || avx/al==cvx/cl || avy/al==cvy/cl)		return null;
		
		var ck:Number = -1;
		if (avx/al==0)		ck = (ax-cx)/cvx*cl;
		else	ck = (cy-ay + (ax-cx)*avy/avx) / (cvx/cl*avy/avx - cvy/cl);
		
		var ak:Number = -1;
		if (cvx/cl==0)		ak = (cx-ax)/avx*al;
		else	ak = (ay-cy + (cx-ax)*cvy/cvx) / (avx/al*cvy/cvx - avy/al);
			
		if (ak<=0 || ak>=al || ck<=0 || ck>=cl)	return null;
			
		return new Point(ax + avx/al*ak,ay + avy/al*ak);
	}//endfunction
		
}//endclass

class Wall extends Sprite
{
	public var joint1:Point;
	public var joint2:Point;
	public var thickness:Number;
	public var Doors:Vector.<Door>;
	
	//=======================================================================================
	//
	//=======================================================================================
	public function Wall(pt1:Point, pt2:Point, thick:Number=10):void
	{
		joint1 = pt1;
		joint2 = pt2;
		thickness = thick;
		Doors = new Vector.<Door>();
	}//endconstr
	
	//=======================================================================================
	// returns perpendicular dist ffom posn to wall, return MAX_VAL if not within wall bounds
	// @param	posn
	// @return
	//=======================================================================================
	public function perpenticularDist(posn:Point):Number
	{
		var wallDir:Point = joint2.subtract(joint1);
		var len:Number = wallDir.length;
		wallDir.x/=len; wallDir.y/=len;
		
		var ptDir:Point = posn.subtract(joint1);
		var proj:Number = ptDir.x*wallDir.x+ptDir.y*wallDir.y;
		if (proj<0 || proj>len) return Number.MAX_VALUE;
		
		return Math.sqrt(ptDir.x*ptDir.x+ptDir.y*ptDir.y - proj*proj);
	}//endfunction
	
	//=======================================================================================
	// returns the 4 corner positions of the wall if it were standalone
	//=======================================================================================
	public function wallBounds(from2:Boolean=false):Vector.<Point>
	{
		var j1:Point = joint1;
		var j2:Point = joint2;
		if (from2)
		{
			j2 = joint1;
			j1 = joint2;
		}
		
		var dv:Point = j2.subtract(j1);
		var f:Number = 0.5*thickness/dv.length;
		dv.x*=f; dv.y*=f;
		
		return Vector.<Point>([	new Point(j1.x-dv.x+dv.y,j1.y-dv.y-dv.x),
								new Point(j2.x+dv.x+dv.y,j2.y+dv.y-dv.x),
								new Point(j2.x+dv.x-dv.y,j2.y+dv.y+dv.x),
								new Point(j1.x-dv.x-dv.y,j1.y-dv.y+dv.x)]);
	}//endfunction
}//endclass

class Door
{
	public var pivot:Number;	// a ratio from joint1 to joint2 of wall	
	public var dir:Number;		// an added ratio relative to pivot
	public var angL:Number=0;
	public var angR:Number=Math.PI/2;
	public var thickness:Number=10;
	
	public function Door(piv:Number,wid:Number):void
	{
		pivot = piv;
		dir = wid;
	}
}//endfunction