package 
{
	import flash.display.Sprite;
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Matrix;
	import flash.geom.Vector3D;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.filters.DropShadowFilter;
	import com.adobe.images.JPGEncoder;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import flash.net.FileReference;
	
	[SWF(width = "1024", height = "768", backgroundColor = "#FFFFFF", frameRate = "30")];
	
	/**
	 * ...
	 * @author mj
	 */
	public class FloorPlanner extends Sprite 
	{
		public static var Copy:XML = 
		<Copy>
		<TopBar>
			<btn ico="MenuIcoFile" en="FILE" cn="文件" />
			<btn ico="MenuIcoFurniture" en="FURNITURE" cn="家具" />
			<btn ico="MenuIcoDrawDoor" en="WINDOWS AND DOORS" cn="门窗" />
			<btn ico="MenuIcoDrawWall" en="DRAW WALLS" cn="画墙壁" />
			<btn ico="MenuIcoText" en="ADD TEXT" cn="文字" />
			<btn ico="MenuIcoSave" en="SAVE IMAGE" cn="保存图片" />
			<btn ico="MenuIcoUndo" en="UNDO" cn="后退" />
			<btn ico="MenuIcoRedo" en="REDO" cn="重做" />
		</TopBar>
		<SaveLoad>
			<NewDocument ico="MenuIcoNew" en="NEW" cn="新建" />
			<NewSave en="SAVE FLOORPLAN" cn="保存户型图" />
			<AskToNew en="CREATE A NEW DOCUMENT?" cn="新建设计，是否放弃当前设计？" />
			<AskToSave en="SAVE THIS FLOORPLAN\nIN A NEW ENTRY?" cn="创造新户型图保存记录" />
			<AskToLoad en="LOAD FLOORPLAN?\nYOUR UNSAVED WORK\nWILL BE LOST!" cn="打开户型图。当前设计会被覆盖！" />
			<Confirm en="CONFIRM" cn="确认" />
			<Cancel en="CANCEL" cn="取消" />
			<DeleteEntry en="DELETE ENTRY" cn="删除这个记录" />
		</SaveLoad>
		<Items>
			<item en="LCD TV" cn="液晶电视" cls="TVFlat" />
			<item en="Toilet Bowl" cn="马桶" cls="Toilet" />
			<item en="Square Table" cn="方桌" cls="TableSquare" />
			<item en="Round Table" cn="f圆桌" cls="TableRound" />
			<item en="Rectangular Table" cn="长方桌" cls="TableRect" />
			<item en="Octagonal Table" cn="八方桌" cls="TableOctagon" />
			<item en="Corner Table" cn="墙角桌" cls="TableL" />
			<item en="Stove" cn="煤气灶" cls="Stove" />
			<item en="2 Seat Sofa" cn="2坐沙发" cls="Sofa2" />
			<item en="3 Seat Sofa" cn="3坐沙发" cls="Sofa3" />
			<item en="4 Seat Sofa" cn="4坐沙发" cls="Sofa4" />
			<item en="Round Sink" cn="洗脸盆" cls="SinkRound" />
			<item en="Kitchen Sink" cn="洗手盆" cls="SinkKitchen" />
			<item en="Piano" cn="钢琴" cls="Piano" />
			<item en="Oven" cn="烘炉" cls="Oven" />
			<item en="Chair" cn="椅子" cls="Chair" />
			<item en="Singale Bed" cn="单人床" cls="BedSingle" />
			<item en="Double Bed" cn="双人床" cls="BedDouble" />
			<item en="Round Bathtub" cn="圆浴缸" cls="BathTubRound" />
			<item en="Corner Bathtub" cn="墙角浴缸" cls="BathTubL" />
			<item en="Bathtub" cn="浴缸" cls="BathTub" />
			<item en="Armchair" cn="靠椅" cls="ArmChair" />
		</Items>
		<Ports>
			<port en="Single Door" cn="单门" cls="DoorSingleSwinging" />
			<port en="Sliding Door" cn="单移门" cls="DoorSingleSliding" />
			<port en="Double Door" cn="双门" cls="DoorDoubleSwinging" />
			<port en="Double Sliding Door" cn="双移门" cls="DoorDoubleSliding" />
			<port en="Small Window" cn="小窗" cls="WindowSingle" />
			<port en="Medium Window" cn="中窗" cls="WindowDouble" />
			<port en="Large Window" cn="大窗" cls="WindowTriple" />
		</Ports>
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
		// takes a 2D snapshot of current floorplan
		//=============================================================================================
		public function saveToJpg():void
		{
			var bnds:Rectangle = floorPlan.overlay.getBounds(floorPlan.overlay);
			var bmd:BitmapData = new BitmapData(bnds.width+60,bnds.height+60,false,0x00000000);
			var mat:Matrix = new Matrix(1,0,0,1,-bnds.left+30,-bnds.top+30);
			bmd.draw(grid,mat);
			bmd.draw(floorPlan.overlay,mat);
			
			var jpgEnc:JPGEncoder = new JPGEncoder(80);
			var ba:ByteArray = jpgEnc.encode(bmd);
			
			var fr:FileReference=new FileReference();
			fr.save(ba, "floorPlan.jpg"); 	
		}//endfunction
		
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
			
			// ----- add grid background --------------------------------------
			grid = new WireGrid();
			grid.x = sw/2;
			grid.y = sh/2;
			grid.update();
			addChild(grid);
			
			// ----- floorplan drawing sprite ---------------------------------
			floorPlan = new FloorPlan();
			grid.addChild(floorPlan.overlay);
			
			// ----- create top bar -------------------------------------------
			topBar = new TopBarMenu(Copy.TopBar.btn,function (i:int):void 
			{
				//prn("TopBarMenu "+i);
				if (i==0)		// file 
				{
					showSaveLoadMenu();
				}
				else if (i==1)	// furniture
				{
					showFurnitureMenu();
					modeDefault();
				}
				else if (i==2)	// doors
				{
					showDoorsMenu();
					modeDefault();
				}
				else if (i==3)	// walls
				{
					modeAddWalls();
				}
				else if (i==4)	// text
				{}
				else if (i==5)	// save o image
				{
					//prn(floorPlan.exportData());
					saveToJpg();
				}
				else if (i==6)	// undo
				{
					if (undoStk.length>0)
					{
						redoStk.push(floorPlan.exportData());
						//prn("undo:" +undoStk[undoStk.length-1]);
						floorPlan.importData(undoStk.pop());
					}
				}
				else if (i==7)	// redo
				{
					if (redoStk.length>0)
					{
						undoStk.push(floorPlan.exportData());
						//prn("undo:" +redoStk[redoStk.length-1]);
						floorPlan.importData(redoStk.pop());
					}
				}
			});
			addChild(topBar);
			
			// ----- zoom slider
			scaleSlider = createVSlider(["0.5x","1x","2x"],function(f:Number):void {grid.zoom(0.5*(1-f)+2*f);});
			scaleSlider.x = stage.stageWidth/20;
			scaleSlider.y = stage.stageHeight/20 + topBar.height;
			addChild(scaleSlider);
			
			// ----- enter default editing mode
			showFurnitureMenu();
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
			floorPlan.importData('{"Furniture":[{"cls":"Toilet","rot":89.70202789452766,"y":-86,"scX":1.2509692700746744,"scY":1.2464523664404727,"x":485},{"cls":"SinkRound","rot":0,"y":-163,"scX":1,"scY":1,"x":451},{"cls":"BathTub","rot":90.4262926392602,"y":37,"scX":1,"scY":1,"x":442},{"cls":"TVFlat","rot":-90.27906677101664,"y":71,"scX":1,"scY":1,"x":-217},{"cls":"TableSquare","rot":0,"y":-117,"scX":1,"scY":1,"x":-164},{"cls":"Sofa4","rot":-89.94349530479464,"y":48,"scX":1,"scY":1,"x":206},{"cls":"Piano","rot":-118.87361735156438,"y":-187,"scX":0.6984775322209045,"scY":0.6855680212976787,"x":-473},{"cls":"BedDouble","rot":-0.14365196037870476,"y":-401,"scX":1,"scY":1,"x":453}],"Walls":[{"j1":2,"Doors":[],"j2":3,"w":20},{"j1":3,"Doors":[{"cls":"WindowSingle","pivot":0.22742261910502903,"dir":0.617154761789942}],"j2":4,"w":10},{"j1":4,"Doors":[{"cls":"WindowSingle","pivot":0.16500000000000004,"dir":0.69}],"j2":5,"w":10},{"j1":5,"Doors":[{"cls":"WindowSingle","pivot":0.15142261910502908,"dir":0.617154761789942}],"j2":6,"w":10},{"j1":6,"Doors":[],"j2":7,"w":20},{"j1":2,"Doors":[],"j2":11,"w":10},{"j1":10,"Doors":[],"j2":11,"w":10},{"j1":1,"Doors":[{"cls":"DoorSingleSwinging","pivot":0.3645320197044335,"dir":0.541871921182266}],"j2":12,"w":10},{"j1":11,"Doors":[{"cls":"DoorSingleSwinging","pivot":0.5444839857651245,"dir":0.3914590747330961}],"j2":12,"w":10},{"j1":14,"Doors":[],"j2":12,"w":10},{"j1":8,"Doors":[],"j2":14,"w":10},{"j1":10,"Doors":[],"j2":14,"w":10},{"j1":0,"Doors":[],"j2":17,"w":10},{"j1":19,"Doors":[{"cls":"DoorSingleSliding","pivot":0.0967153284671533,"dir":0.7846715328467153}],"j2":17,"w":20},{"j1":19,"Doors":[{"cls":"WindowSingle","pivot":0.2247734199204044,"dir":0.5440496786546839}],"j2":21,"w":10},{"j1":21,"Doors":[{"cls":"WindowSingle","pivot":0.27884615384615385,"dir":0.4423076923076923}],"j2":22,"w":10},{"j1":22,"Doors":[{"cls":"WindowSingle","pivot":0.24911822040192444,"dir":0.5231477854550612}],"j2":23,"w":10},{"j1":23,"Doors":[{"cls":"WindowSingle","pivot":0.1859504132231405,"dir":0.5702479338842975}],"j2":24,"w":10},{"j1":24,"Doors":[],"j2":25,"w":10},{"j1":7,"Doors":[],"j2":26,"w":10},{"j1":17,"Doors":[{"cls":"DoorSingleSwinging","pivot":0.0578512396694215,"dir":0.2272727272727273}],"j2":26,"w":10},{"j1":25,"Doors":[{"cls":"WindowDouble","pivot":0.08012820512820518,"dir":0.8269230769230769}],"j2":26,"w":10},{"j1":8,"Doors":[{"cls":"WindowDouble","pivot":0.5289115646258504,"dir":0.4387755102040816}],"j2":27,"w":10},{"j1":1,"Doors":[],"j2":27,"w":10},{"j1":0,"Doors":[{"cls":"DoorDoubleSwinging","pivot":0.25052731917835847,"dir":0.4448862062046374}],"j2":1,"w":10}],"Joints":[{"y":-396,"x":-250},{"y":-394,"x":249},{"y":180,"x":250},{"y":180,"x":150},{"y":230,"x":50},{"y":230,"x":-50},{"y":180,"x":-150},{"y":180,"x":-250},{"y":-517,"x":543},{"y":-394,"x":249},{"y":89,"x":543},{"y":89,"x":249},{"y":-192,"x":249},{"y":-192,"x":249},{"y":-192,"x":543},{"y":-192,"x":249},{"y":-192,"x":543},{"y":-343,"x":-250},{"y":-343,"x":-250},{"y":-343,"x":-524},{"y":-343,"x":-250},{"y":-269,"x":-627},{"y":-113,"x":-627},{"y":-27,"x":-527},{"y":-27,"x":-406},{"y":141,"x":-406},{"y":141,"x":-250},{"y":-517,"x":249},{"y":-394,"x":249}]}');
			floorPlan.refresh();
		}//endfunction
		
		//=============================================================================================
		// show save load selection
		//=============================================================================================
		private function showSaveLoadMenu():void
		{
			var px:int = stage.stageWidth;
			var py:int = topBar.height+5;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new SaveLoadMenu(floorPlan);
			menu.x = Math.min(px,stage.stageWidth-menu.width-5);
			menu.y = py;
			addChild(menu);
		}//endfunction
		
		//=============================================================================================
		// show available furniture selection
		//=============================================================================================
		private function showFurnitureMenu():void
		{
			var px:int = stage.stageWidth;
			var py:int = topBar.height+5;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new AddFurnitureMenu(Copy.Items[0].item,floorPlan,function(idx:int):void
			{
				var IcoCls:Class = Class(getDefinitionByName(Copy.Items[0].item[idx].@cls));
				floorPlan.addFurniture(new IcoCls());
			});
			menu.x = Math.min(px,stage.stageWidth-menu.width-5);
			menu.y = py;
			addChild(menu);
		}//endfunction
		
		//=============================================================================================
		// show available doors windows selection
		//=============================================================================================
		private function showDoorsMenu():void
		{
			var px:int = stage.stageWidth;
			var py:int = topBar.height+5;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new AddFurnitureMenu(Copy.Ports[0].port,floorPlan,function(idx:int):void
			{
				var IcoCls:Class = Class(getDefinitionByName(Copy.Ports[0].port[idx].@cls));
				modeAddDoors(new IcoCls() as Sprite);
			});	
			menu.x = Math.min(px,stage.stageWidth-menu.width-5);
			menu.y = py;
			addChild(menu);
		}//endfunction
		
		//=============================================================================================
		// go into defacto edit mode
		//=============================================================================================
		private function modeDefault():void
		{
			//prn("modeDefault");
			var px:int = 0;
			var py:int = topBar.height+5;
			
			function showDoorProperties(door:Door):void
			{
				var wall:Wall = null;
				for (var i:int=floorPlan.Walls.length-1; i>-1; i--)
					if (floorPlan.Walls[i].Doors.indexOf(door)!=-1)
						wall = floorPlan.Walls[i];
				if (menu!=null)
				{
					if (menu.parent!=null) menu.parent.removeChild(menu);
					px = menu.x;
					py = menu.y;
				}
				menu = new DialogMenu("PROPERTIES",
										Vector.<String>(["LENGTH ["+Math.abs(door.dir)+"]","REMOVE","DONE"]),
										Vector.<Function>([	function(val:String):void 
															{
																if (door.dir<0)
																	door.dir = -Math.min(1,Math.max(0.01,Number(val)));
																else
																	door.dir = Math.min(1,Math.max(0.01,Number(val)));
																floorPlan.refresh();
															},
															function():void 
															{
																wall.removeDoor(door);
																floorPlan.drawWall(wall);
																showFurnitureMenu();
															},
															showFurnitureMenu]));
				menu.x = px;
				menu.y = py;
				stage.addChild(menu);
			}//endfunction
			// ---------------------------------------------------------------------
			function showWallProperties(wall:Wall):void
			{
				if (menu!=null)
				{
					if (menu.parent!=null) menu.parent.removeChild(menu);
					px = menu.x;
					py = menu.y;
				}
				menu = new DialogMenu("PROPERTIES",
										Vector.<String>(["THICKNESS ["+wall.thickness+"]","REMOVE","DONE"]),
										Vector.<Function>([	function(val:String):void 
															{
																wall.thickness = Math.max(5,Math.min(30,Number(val)));
																floorPlan.refresh();
															},
															function():void 
															{
																floorPlan.removeWall(wall);
																floorPlan.refresh();
																showFurnitureMenu();
															},
															showFurnitureMenu]));
				menu.x = px;
				menu.y = py;
				stage.addChild(menu);
			}//endfunction
			// ---------------------------------------------------------------------
			
			floorPlan.selected = null;
						
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
								floorPlan.refresh();
							}
						}
						else	// joint wall end to existing wall
						{
							var snapW:Wall = floorPlan.nearestNonAdjWall(selJ, snapDist);
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
					else if (floorPlan.selected is Door)
					{
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
			// ----------------------------------------------------------------
			mouseDownFn = function():void
			{
				prevMousePt.x = grid.mouseX;
				prevMousePt.y = grid.mouseY;
				
				floorPlan.mouseSelect();				// chk if anything selected
				
				if (floorPlan.selected!=null)			// save for undo
					undoStk.push(floorPlan.exportData());
				
				if (floorPlan.selected is Point)		// selected a joint
				{	
				}
				else if (floorPlan.selected is Wall)	// selected a wall
				{
					showWallProperties((Wall)(floorPlan.selected));
				}
				else if (floorPlan.selected is Door)	// selected a door
				{
					showDoorProperties((Door)(floorPlan.selected));
				}
				else if (floorPlan.selected!=null)		// selected a furniture
				{
				}
				else
				{
					showFurnitureMenu();
					floorPlan.refresh();
					prn("floorPlan.selected="+floorPlan.selected+"   "+floorPlan.debugStr);
				}
			}
			// ----------------------------------------------------------------
			mouseUpFn = function():void
			{
				if (undoStk.length>0 && floorPlan.exportData()==undoStk[undoStk.length-1]) 
					undoStk.pop();	// if no state change 
			}
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
			menu = new DialogMenu("ADDING WALLS",
									Vector.<String>(["DONE"]),
									Vector.<Function>([function():void {showFurnitureMenu(); modeDefault();}]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
		
			// ----------------------------------------------------------------
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
							//prn("modeAddWalls replacingJoint");
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
			// ----------------------------------------------------------------
			mouseDownFn = function():void
			{
				undoStk.push(floorPlan.exportData());
				if (wall==null)
				{
					wall = floorPlan.createWall(new Point(grid.mouseX,grid.mouseY),
												new Point(grid.mouseX,grid.mouseY),
												snapDist);
				}
			}
			// ----------------------------------------------------------------
			mouseUpFn = function():void
			{
				if (wall!=null && wall.joint1.subtract(wall.joint2).length<=snapDist)
				{
					floorPlan.removeWall(wall);		// remove wall stub
					floorPlan.refresh();
				}
				wall = null;
				
				if (undoStk.length>0 && undoStk[undoStk.length-1]==floorPlan.exportData())
					undoStk.pop();
			}
		}//endfunction
		
		//=============================================================================================
		// go into adding doors mode
		//=============================================================================================
		private function modeAddDoors(ico:Sprite,snapDist:Number=10):void
		{
			var px:int = 0;
			var py:int = 0;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new DialogMenu("ADDING DOORS",
									Vector.<String>(["DONE"]),
									Vector.<Function>([function():void {showDoorsMenu(); modeDefault();}]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
			
			// ----- add doors logic
			var icoW:int = ico.width;
			var prevWall:Wall = null;
			var door:Door = new Door(0,0.5,ico);	// pivot and dir values to be replaced
			
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
				
				var near:Wall = floorPlan.nearestNonAdjWall(mouseP,snapDist);
				var doorP:Point = null;
				if (near!=null)	
				{
					doorP = near.chkPlaceDoor(mouseP, icoW);	// chk place door of 100 width
				}
				// ----- if in position to place door
				//prn("near="+near+"  doorP="+doorP)
				if (near!=null && doorP!=null)
				{
					door.pivot = doorP.x;
					door.dir = icoW/(near.joint2.subtract(near.joint1).length);	// calculate ratio of occupied wall
					near.addDoor(door);
					floorPlan.drawWall(near);
					prevWall = near;
				}
				
				// ----- hack to prevent immediate mouseUp
				mouseUpFn = function():void
				{
					modeDefault();
					showDoorsMenu();
				}
			}//endfunction
			mouseDownFn = function():void
			{
				
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
				//debugTf.mouseEnabled = false;
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
			slider.y = h/2;
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
import flash.display.Loader;
import flash.events.FocusEvent;
import flash.geom.Point;
import flash.geom.Vector3D;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.geom.ColorTransform;
import flash.text.TextField;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.filters.GlowFilter;
import flash.filters.DropShadowFilter;
import flash.text.TextFormat;
import flash.utils.getTimer;
import flash.utils.ByteArray;
import flash.utils.getDefinitionByName;
import flash.utils.getQualifiedClassName;
import flash.net.SharedObject;
import com.adobe.images.JPGEncoder;

class FloatingMenu extends Sprite		// to be extended
{
	protected var Btns:Vector.<Sprite> = null;
	protected var callBackFn:Function = null;
	protected var overlay:Sprite = null;			// something on top to disable this
	
	//===============================================================================================
	// simpleton constructor, subclasses must initialize Btns and callBackFn
	//===============================================================================================
	public function FloatingMenu():void
	{
		filters = [new DropShadowFilter(4,90,0x000000,1,4,4,0.5)];
		addEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		addEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		addEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		addEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onMouseDown(ev:Event):void
	{
		if (stage==null) return;
		this.startDrag();
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onMouseUp(ev:Event):void
	{
		if (stage==null) return;
		this.stopDrag();
		if (overlay!=null) return;
		if (Btns!=null)
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].parent==this && Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				if  (callBackFn!=null) callBackFn(i);	// exec callback function
				return;
			}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onEnterFrame(ev:Event):void
	{
		if (overlay!=null && overlay.parent!=this) overlay=null;
		if (stage==null) return;
		
		var A:Array = null;
		
		if (Btns!=null)
		for (var i:int=Btns.length-1; i>-1; i--)
			if (overlay==null && Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				A = Btns[i].filters;
				if (A.length==0)
					Btns[i].filters=[new GlowFilter(0x000000,1,4,4,1)];
				else if ((GlowFilter)(A[0]).strength<1)
					(GlowFilter)(A[0]).strength+=0.1;
			}
			else
			{
				if (Btns[i].filters.length>0)
				{
					A = Btns[i].filters;
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
	protected function onRemove(ev:Event):void
	{
		removeEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		removeEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		removeEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		removeEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// draws a striped rectangle in given sprite 
	//===============================================================================================
	protected static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
	{
		if (s==null)	s = new Sprite();
		var mat:Matrix = new Matrix();
		mat.createGradientBox(sw,sw,rot,0,0);
		s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
		s.graphics.drawRoundRect(x,y,w,h,rnd,rnd);
		s.graphics.endFill();
		
		return s;
	}//endfunction 
}//endclass

class IconsMenu extends FloatingMenu	
{
	private var pageIdx:int=0;
	private var pageBtns:Sprite = null;
	private var r:int = 1;		// rows
	private var c:int = 1;		// cols
	private var bw:int = 50;	// btn width
	private var bh:int = 50;	// btn height
	private var marg:int = 10;
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function IconsMenu(Icos:Vector.<Sprite>,rows:int,cols:int,callBack:Function):void
	{
		Btns = Icos;
		callBackFn = callBack;
	
		if (rows<1)	rows = 1;
		if (cols<1) cols = 1;
		r = rows;
		c = cols;
		pageBtns = new Sprite();
		addChild(pageBtns);
		
		refresh();
		
		function pageBtnsClickHandler(ev:Event) : void
		{
			for (var i:int=pageBtns.numChildren-1; i>-1; i--)
				if (pageBtns.getChildAt(i).hitTestPoint(stage.mouseX,stage.mouseY))
					pageTo(i);
		}
		function pageBtnsRemoveHandler(ev:Event) : void
		{
			pageBtns.removeEventListener(MouseEvent.CLICK,pageBtnsClickHandler);
			pageBtns.removeEventListener(Event.REMOVED_FROM_STAGE,pageBtnsRemoveHandler);
		}
		
		pageBtns.addEventListener(MouseEvent.CLICK,pageBtnsClickHandler);
		pageBtns.addEventListener(Event.REMOVED_FROM_STAGE,pageBtnsRemoveHandler);
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function refresh():void
	{
		var tw:int=0;
		var th:int=0;
		for (var i:int=Btns.length-1; i>-1; i--)
		{
			tw+=Btns[i].width;
			th+=Btns[i].height;
		}
		if (tw>0)	bw = tw/Btns.length;
		if (th>0)	bh = th/Btns.length;
		
		// ----- update pageBtns to show correct pages
		var pageCnt:int = Math.ceil(Btns.length/(r*c));
		while (pageBtns.numChildren>pageCnt)	
			pageBtns.removeChildAt(pageBtns.numChildren-1);
		for (i=0; i<pageCnt; i++)
		{
			var sqr:Sprite = new Sprite();
			sqr.graphics.beginFill(0x666666,1);
			sqr.graphics.drawRect(0,0,9,9);
			sqr.graphics.endFill();
			sqr.x = i*(sqr.width+10);
			sqr.buttonMode = true;
			pageBtns.addChild(sqr);
		}
		
		if (pageCnt>1)
		{
			pageBtns.visible=true;
			drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3+marg*2,0xFFFFFF,0xF6F6F6,20,10);
		}
		else
		{
			pageBtns.visible=false;
			drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3,0xFFFFFF,0xF6F6F6,20,10);
		}
		pageBtns.x = (this.width-pageBtns.width)/2;
		pageBtns.y =this.height-marg*2-pageBtns.height/2;
		
		pageTo(pageIdx);
	}//endfunction
	
	//===============================================================================================
	// go to page number
	//===============================================================================================
	public function pageTo(idx:int):void
	{
		while (numChildren>1)	removeChildAt(1);	// child 0 is pageBtns
		
		if (idx<0)	idx = 0;
		if (idx>Math.ceil(Btns.length/(r*c)))	idx = Math.ceil(Btns.length/(r*c));
		var a:int = idx*r*c;
		var b:int = Math.min(Btns.length,a+r*c);
		for (var i:int=a; i<b; i++)
		{
			var btn:Sprite = Btns[i];
			btn.x = marg*2+(i%c)*(bw+marg)+(bw-btn.width)/2;
			btn.y = marg*2+int((i-a)/c)*(bh+marg)+(bh-btn.height)/2;
			addChild(btn);
		}
		
		for (i=pageBtns.numChildren-1; i>-1; i--)
		{
			if (i==idx)
				pageBtns.getChildAt(i).transform.colorTransform = new ColorTransform(1,1,1,1,70,70,70);
			else
				pageBtns.getChildAt(i).transform.colorTransform = new ColorTransform();
		}
		pageIdx = idx;
	}//endfunction	
}//endclass

class TopBarMenu extends FloatingMenu
{
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
			tff.size = 12;
			tff.color = 0x888888;
			tf.defaultTextFormat = tff;
			tf.text = labels[i].@cn;
			var b:Sprite = new Sprite();
			if (getDefinitionByName(labels[i].@ico)!=null)
			{
				var ico:Sprite = new (Class(getDefinitionByName(labels[i].@ico)))();
				tf.x = ico.width+5;
				b.addChild(ico);
			}
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
			for (var j:int=btn.numChildren-1; j>-1; j--)
			{
				var e:DisplayObject = btn.getChildAt(j);
				e.y = (btn.height-e.height)/2;
				e.x+=5;
			}
		}
		
		// ----- aligning btns
		var hh:int = this.height;
		var offX:int=20;
		for (i=0; i<n; i++)
		{
			var c:DisplayObject = this.getChildAt(i);
			c.x = offX;
			c.y = (hh+10-c.height)/2;
			offX += c.width+20;
			var lin:Sprite = new Sprite();
			lin.graphics.lineStyle(0,0x888888);
			lin.graphics.lineTo(0,hh*0.8);
			lin.x = offX-10;
			lin.y = (hh+10-lin.height)/2;
			addChild(lin);
		}
			
		var ppp:Sprite = this;
		function onResize(ev:Event):void
		{
			ppp.graphics.clear();
			drawStripedRect(ppp,0,0,stage.stageWidth,ppp.height+10,0xFFFFFF,0xF6F6F6,0,10);
		}
		function onAddedToStage(ev:Event):void
		{
			drawStripedRect(ppp,0,0,stage.stageWidth,ppp.height+10,0xFFFFFF,0xF6F6F6,0,10);
			ppp.removeEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
			stage.addEventListener(Event.RESIZE,onResize);
		}
		ppp.addEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
	}//endfunction
}//endclass

class DialogMenu extends FloatingMenu
{
	private var Fns:Vector.<Function> = null;
	private var titleTf:TextField = null;

	//===============================================================================================
	// 
	//===============================================================================================
	public function DialogMenu(title:String,labels:Vector.<String>,callBacks:Vector.<Function>):void
	{
		Fns = callBacks;
		
		// ----- create title
		titleTf = new TextField();
		var tff:TextFormat = titleTf.defaultTextFormat;
		tff.font = "arial";
		tff.color = 0x888888;
		tff.bold = true;
		tff.size = 15;
		tff.align = "center";
		titleTf.defaultTextFormat = tff;
		titleTf.text = title;
		titleTf.autoSize = "left";
		titleTf.wordWrap = false;
		titleTf.selectable = false;
		addChild(titleTf);
		tff.size = 12;
		
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
		
		callBackFn = function(idx:int):void
		{
			if (Btns[idx].numChildren>1)
			{
				var itf:TextField = (TextField)(Btns[idx].getChildAt(1));
				if (itf.type=="input")
				{
					itf.type="dynamic"
					itf.background = false;
					Fns[idx](itf.text);
				}
				else
				{
					itf.type = "input";
					itf.background = true;
					if (stage.focus!=itf)
					{
						stage.focus = itf;
					}
				}
			}
			else
				Fns[idx]();	// exec callback function
		}//endfunction
	}//endfunction
}//endclass

class AddFurnitureMenu extends IconsMenu
{
	private var IcoCls:Vector.<Class> = null;
	private var floorPlan:FloorPlan = null;
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function AddFurnitureMenu(dat:XMLList,floorP:FloorPlan,callBackFn:Function,icoW:int=70):void
	{
		Btns = new Vector.<Sprite>();
		IcoCls = new Vector.<Class>();
		floorPlan = floorP;
		
		for (var i:int=0; i<dat.length(); i++)
		{
			var btn:Sprite = new Sprite();
			btn.graphics.beginFill(0xFFFFFF,1);
			btn.graphics.drawRoundRect(0,0,icoW,icoW,icoW/10,icoW/10);
			btn.graphics.endFill();
			IcoCls.push(getDefinitionByName(dat[i].@cls));
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
				tf.text = dat[i].@cn;
			}
			while (tf.width>icoW);
			tf.y = btn.height;
			tf.x = (btn.width-tf.width)/2;
			btn.addChild(tf);
			Btns.push(btn);
		}
		
		super(Btns,3,2,callBackFn);		// menu of 3 rows by 2 cols
	}//endfunction
	
}//endclass

class SaveLoadMenu extends IconsMenu
{
	private var floorPlan:FloorPlan;
	private var hasInit:Boolean = false;
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function SaveLoadMenu(floorP:FloorPlan):void
	{
		floorPlan = floorP;
				
		callBackFn = function(idx:int):void
		{
			if (idx==0)			// new document
				askToNew();
			else if (idx==1)	// save file
				askToSave();
			else				// load saved data
				askToLoad(idx-2);
		}//endfunction
		
		var so:SharedObject = SharedObject.getLocal("FloorPlanner");
		var saveDat:Array = so.data.savedData;	// name,tmbByteArr,datastring
		if (saveDat==null)	saveDat = [];
		
		updateBtns();
		super(Btns,3,2,callBackFn);		// menu of 3 rows by 2 cols
		hasInit = true;
	}//endconstr
	
	//===============================================================================================
	// dialog to confirm save
	//===============================================================================================
	function askToNew():void
	{
		var askNew:Sprite = new DialogMenu(FloorPlanner.Copy.SaveLoad.AskToNew.@cn,
									Vector.<String>([	FloorPlanner.Copy.SaveLoad.Confirm.@cn,
														FloorPlanner.Copy.SaveLoad.Cancel.@cn]),
									Vector.<Function>([function():void 
														{
															floorPlan.clearAll();
															overlay.parent.removeChild(overlay);
														},
														function():void 
														{
															overlay.parent.removeChild(overlay);
														}])); 
		askNew.x = (this.width-askNew.width)/2;
		askNew.y = (this.height-askNew.height)/2;
		overlay = new Sprite();
		overlay.graphics.beginFill(0xFFFFFF,0.5);
		overlay.graphics.drawRoundRect(0,0,this.width,this.height,20);
		overlay.graphics.endFill();
		overlay.addChild(askNew);
		addChild(overlay);
	}//endfunction
	
	//===============================================================================================
	// dialog to confirm save
	//===============================================================================================
	function askToSave():void
	{
		var askSaveFile:Sprite = new DialogMenu(FloorPlanner.Copy.SaveLoad.AskToSave.@cn,
									Vector.<String>([	FloorPlanner.Copy.SaveLoad.Confirm.@cn,
														FloorPlanner.Copy.SaveLoad.Cancel.@cn]),
									Vector.<Function>([function():void 
														{
															saveToSharedObject();
															overlay.parent.removeChild(overlay);
															updateBtns();
														},
														function():void 
														{
															overlay.parent.removeChild(overlay);
														}])); 
		askSaveFile.x = (this.width-askSaveFile.width)/2;
		askSaveFile.y = (this.height-askSaveFile.height)/2;
		overlay = new Sprite();
		overlay.graphics.beginFill(0xFFFFFF,0.5);
		overlay.graphics.drawRoundRect(0,0,this.width,this.height,20);
		overlay.graphics.endFill();
		overlay.addChild(askSaveFile);
		addChild(overlay);
	}//endfunction
	
	//===============================================================================================
	// dialog to load data
	//===============================================================================================
	function askToLoad(idx:int):void
	{
		var askLoadFile:Sprite = new DialogMenu(FloorPlanner.Copy.SaveLoad.AskToLoad.@cn,
									Vector.<String>([	FloorPlanner.Copy.SaveLoad.Confirm.@cn,
														FloorPlanner.Copy.SaveLoad.Cancel.@cn,
														FloorPlanner.Copy.SaveLoad.DeleteEntry.@cn]),
									Vector.<Function>([function():void 
														{	// LOAD
															var so:SharedObject = SharedObject.getLocal("FloorPlanner");
															var saveDat:Array = so.data.savedData;	// name,tmbByteArr,datastring
															floorPlan.importData(saveDat[(idx)*3+2]);
															overlay.parent.removeChild(overlay);
														},
														function():void 
														{	// CANCEL
															overlay.parent.removeChild(overlay);
														},
														function():void 
														{	// DELETE
															var so:SharedObject = SharedObject.getLocal("FloorPlanner");
															var saveDat:Array = so.data.savedData;	// name,tmbByteArr,datastring
															saveDat.splice((idx)*3,3);
															so.data.savedData = saveDat;
															so.flush();
															overlay.parent.removeChild(overlay);
															updateBtns();
														}])); 
		askLoadFile.x = (this.width-askLoadFile.width)/2;
		askLoadFile.y = (this.height-askLoadFile.height)/2;
		overlay = new Sprite();
		overlay.graphics.beginFill(0xFFFFFF,0.5);
		overlay.graphics.drawRoundRect(0,0,this.width,this.height,20);
		overlay.graphics.endFill();
		overlay.addChild(askLoadFile);
		addChild(overlay);
	}//endfunction
	
	//===============================================================================================
	// Refresh buttons after save operation etc
	//===============================================================================================
	function updateBtns():void
	{
		Btns = new Vector.<Sprite>();
		
		// --------------------------------------------------------------------
		function makeBtn(ico:DisplayObject,txt:String):void
		{
			var btn:Sprite = new Sprite();
			btn.graphics.beginFill(0xFFFFFF,1);
			btn.graphics.drawRoundRect(0,0,100,100,10);
			btn.graphics.endFill();
			ico.x = (btn.width-ico.width)/2;
			ico.y = (btn.height-ico.height)/2;
			btn.addChild(ico);
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			do {
				var tff:TextFormat = tf.defaultTextFormat;
				tff.color = 0x000000;
				tff.size = int(tff.size)-1;
				tf.defaultTextFormat = tff;
				tf.text = txt;
			}
			while (tf.width>btn.width);
			tf.y = btn.height;
			tf.x = (btn.width-tf.width)/2;
			btn.addChild(tf);
			Btns.push(btn);
		}
		// --------------------------------------------------------------------
		function showSaveFiles(saveDat:Array):void
		{
			var idx:int=0;
			
			function loadNext():void
			{
				var ldr:Loader = new Loader();
				ldr.loadBytes(saveDat[idx+1] as ByteArray);
				function imgLoaded(ev:Event):void
				{
					makeBtn(ldr.content,saveDat[idx]);	// create button with icon and label
					ldr.contentLoaderInfo.removeEventListener(Event.COMPLETE, imgLoaded);
					idx+=3;
					if (idx>=saveDat.length)
					{
						if (hasInit) 	refresh();
					}
					else
						loadNext();
				}
				ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, imgLoaded);
			}
			if (saveDat.length>idx)	loadNext();
		}//endfunction
				
		makeBtn(new MenuIcoNew(),FloorPlanner.Copy.SaveLoad.NewDocument.@cn);
		makeBtn(new MenuIcoSave(),FloorPlanner.Copy.SaveLoad.NewSave.@cn);
		
		var so:SharedObject = SharedObject.getLocal("FloorPlanner");
		var saveDat:Array = so.data.savedData;	// name,tmbByteArr,datastring
		if (saveDat==null)	saveDat = [];
		showSaveFiles(saveDat);
	}//endfunction
	
	//===============================================================================================
	// write floorplan data to SharedObject
	//===============================================================================================
	function saveToSharedObject():void
	{
		var bnds:Rectangle = floorPlan.overlay.getBounds(floorPlan.overlay);
		var bmd:BitmapData = new BitmapData(90,90,false,0xFFFFFF);
		var sc:Number = Math.min(90/bnds.width,90/bnds.height);
		var mat:Matrix = new Matrix(sc,0,0,sc,-bnds.left*sc+(bmd.width-bnds.width*sc)/2,-bnds.top*sc+(bmd.height-bnds.height*sc)/2);
		bmd.draw(floorPlan.overlay,mat,null,null,null,true);
		var jpgEnc:JPGEncoder = new JPGEncoder(80);
		var ba:ByteArray = jpgEnc.encode(bmd);
		var M:Array = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
		var dat:Date = new Date();
		
		var so:SharedObject = SharedObject.getLocal("FloorPlanner");
		var saveDat:Array = so.data.savedData;	// name,tmbByteArr,datastring
		if (saveDat==null) saveDat = [];
		saveDat.unshift(dat.date+" "+M[dat.month]+" "+dat.fullYear , ba , floorPlan.exportData());
		if (saveDat.length>20*3) saveDat = saveDat.slice(0,20*3);
		so.data.savedData = saveDat;
		so.flush();
		
	}//endfunction
	
}//endclass

class WireGrid extends Sprite
{
	//=============================================================================================
	// constructor for background grid markings sprite
	//=============================================================================================
	public function WireGrid():void
	{
		var ppp:Sprite = this;
		function onResize(ev:Event):void
		{
			update();
		}
		function onAddedToStage(ev:Event):void
		{
			update();
			ppp.removeEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
			stage.addEventListener(Event.RESIZE,onResize);
		}
		ppp.addEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	public function zoom(sc:Number):void
	{
		if (stage==null) return;
		var sw:int = stage.stageWidth;
		var sh:int = stage.stageHeight;
		
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
		if (stage==null) return;
		var sw:int = stage.stageWidth;
		var sh:int = stage.stageHeight;
		
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
	// removes everything and start from clean slate
	//=============================================================================================
	public function clearAll():void
	{
		selected = null;		// clear off selection
		
		if (furnitureCtrls!=null)
		{
			furnitureCtrls.parent.removeChild(furnitureCtrls);		// clear off furniture transform controls
			furnitureCtrls = null;
		}
		
		// ----- remove joints
		Joints = new Vector.<Point>();
		
		// ----- remove walls
		while (Walls.length>0)					// clear off prev walls
			overlay.removeChild(Walls.pop());
				
		// ----- remove furniture
		while (Furniture.length>0)				// clear off prev furniture
			overlay.removeChild(Furniture.pop());
		
		refresh();
	}//endfunction
	
	//=============================================================================================
	// covert data to JSON formatted string
	//=============================================================================================
	public function exportData():String
	{
		var o:Object = new Object();
		o.Joints = Joints;
		o.Walls = Walls;
		o.Furniture = Furniture;
		
		function replacer(k,v):*
		{
			if (v is Door)			//
			{
				var o:Object = new Object();
				o.pivot = v.pivot;
				o.dir = v.dir;
				o.cls = getQualifiedClassName((Door)(v).icon);
				return o;
			}
			else if (v is Wall)		// joints become indexes
			{
				var wo:Object = new Object();
				wo.j1 = Joints.indexOf((Wall)(v).joint1);
				wo.j2 = Joints.indexOf((Wall)(v).joint2);
				wo.w = (Wall)(v).thickness;
				wo.Doors = (Wall)(v).Doors;
				return wo;
			}
			else if (v is Sprite)	// furniture icons properties
			{
				var fo:Object = new Object();
				fo.cls = getQualifiedClassName(v);
				fo.x = v.x;
				fo.y = v.y;
				fo.rot = v.rotation;
				fo.scX = v.scaleX;
				fo.scY = v.scaleY;
				return fo;
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
		selected = null;		// clear off selection
		
		if (furnitureCtrls!=null)
		{
			furnitureCtrls.parent.removeChild(furnitureCtrls);		// clear off furniture transform controls
			furnitureCtrls = null;
		}
		
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
				var doorIco:Sprite = new (Class(getDefinitionByName(d.cls)))() as Sprite;
				var door:Door = new Door(Number(d.pivot),Number(d.dir),doorIco);
				wall.addDoor(door);
			}
			overlay.addChild(wall);
			Walls.unshift(wall);
		}
		
		// ----- replace furniture
		while (Furniture.length>0)				// clear off prev furniture
			overlay.removeChild(Furniture.pop());
		for (i=o.Furniture.length-1; i>-1; i--)		// add in new walls
		{
			var fo:Object = o.Furniture[i];
			var fur:Sprite = new (Class(getDefinitionByName(fo.cls)))() as Sprite;
			fur.x = fo.x;
			fur.y = fo.y;
			fur.rotation = fo.rot;
			fur.scaleX = fo.scX;
			fur.scaleY = fo.scY;
			Furniture.unshift(fur);
			overlay.addChild(fur);
		}
		
		refresh();
	}//endfunction
	
	//=============================================================================================
	// creates and add wall to floorplan 
	//=============================================================================================
	public function createWall(pt1:Point, pt2:Point, width:Number=10, snapDist:Number=10):Wall
	{
		function registerWall(wall:Wall):Wall
		{
			Walls.push(wall);
			drawWall(wall);
			overlay.addChild(wall);
			return wall;
		}
	
		// ----- snap pt1 to existing joint if near
		var nearest:Point = nearestJoint(pt1,snapDist);
		if (nearest!=null)	
			pt1 = nearest;
		else
		{	// snap starting point to nearest wall if approprate
			var snapW:Wall = nearestNonAdjWall(pt1, snapDist);
			if (snapW!=null)	
			{
				pt1 = projectedWallPosition(snapW, pt1);
				removeWall(snapW);
				registerWall(new Wall(snapW.joint1, pt1));
				registerWall(new Wall(snapW.joint2, pt1));
			}
			Joints.push(pt1);
		}
		
		// ----- snap pt2 to existing joint not pt1
		nearest = null;
		for (var i:int=Joints.length-1; i>-1; i--)
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
		return registerWall(new Wall(pt1, pt2, width));
	}//endfunction
	
	//=============================================================================================
	// cleanly remove wall and its unused joints
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
	// replace joint with given new joint, used for snapping together wall joints
	//=============================================================================================
	public function replaceJointWith(jt:Point,njt:Point):void
	{
		if (Joints.indexOf(njt)!=-1)	// njt already exists
		{	// remove jt
			if (Joints.indexOf(jt)!=-1)	Joints.splice(Joints.indexOf(jt),1);
		}
		else
		{	// else replace with njt
			if (Joints.indexOf(jt)==-1)	Joints.push(njt);
			else						Joints[Joints.indexOf(jt)]=njt;
		}
		
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var wall:Wall = Walls[i];
			if (wall.joint1==jt)	wall.joint1=njt;
			if (wall.joint2==jt)	wall.joint2=njt;
			if (wall.joint1==wall.joint2)
			{	// remove any 0 lengthwall
				removeWall(wall);
			}
		}
	}//endfunction
	
	//=============================================================================================
	// finds the nearest wall to this position, where posn cannot be joint1 or joint2
	//=============================================================================================
	public function nearestNonAdjWall(posn:Point,cutOff:Number):Wall
	{
		var wall:Wall = null;
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var w:Wall = Walls[i];
			if (w.joint1!=posn && w.joint2!=posn && cutOff>w.perpenticularDist(posn))
			{
				wall = w;
				cutOff = wall.perpenticularDist(posn);
			}
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
			if (selected==door)	
				drawBar(wall,piv,piv.add(dir),wall.thickness,0xFF6600);	
			else
				drawBar(wall,piv,piv.add(dir),wall.thickness,0xEEEEEE);
			door.icon.x = piv.x+dir.x/2;
			door.icon.y = piv.y+dir.y/2;
			door.icon.rotation = 0;
			door.icon.width = dir.length;
			door.icon.scaleY = door.icon.scaleX;
			door.icon.rotation = bearing*180/Math.PI+90;
			wall.addChild(door.icon);
			/*
			var angL:Number = bearing+door.angL;
			var angR:Number = bearing+door.angR;
			wall.graphics.lineStyle(0,0x000000,1);
			var cnt:int = 0;
			wall.graphics.moveTo(piv.x,piv.y);
			for (var deg:Number=angL; deg<angR; deg+=Math.PI/32)	// draw the arc
			{
				if (cnt%2==0)
					wall.graphics.lineTo(piv.x+Math.sin(deg)*dir.length,piv.y-Math.cos(deg)*dir.length);
				else
					wall.graphics.moveTo(piv.x+Math.sin(deg)*dir.length,piv.y-Math.cos(deg)*dir.length);
				cnt++;
			}
			drawBar(wall,piv,piv.add(new Point(Math.sin(angL)*dir.length,-Math.cos(angL)*dir.length)),door.thickness);
			drawBar(wall,piv,piv.add(new Point(Math.sin(angR)*dir.length,-Math.cos(angR)*dir.length)),door.thickness);
			*/
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
		var i:int=0;
		if (furnitureCtrls!=null)
		{
			if (furnitureCtrls.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY)) 
				return selected;
			furnitureCtrls.parent.removeChild(furnitureCtrls);		// clear off furniture transform controls
			furnitureCtrls = null;
		}
		
		selected = null;	// clear prev selected
		
		for (i=Furniture.length-1; i>-1; i--)
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
		{
			selected = nearestNonAdjWall(new Point(overlay.mouseX,overlay.mouseY), 10);		// chk if near any wall
			if (selected!=null)
			{
				var wall:Wall = selected as Wall;
				for (i=wall.Doors.length-1; i>-1; i--)
					if (wall.Doors[i].icon.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY))
						selected = wall.Doors[i];
			}
		}
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
	private function drawBar(s:Sprite,from:Point,to:Point,thickness:Number,color:uint=0xCCCCCC):void
	{
		var dir:Point = to.subtract(from);
		var dv:Point = new Point(dir.x/dir.length*thickness/2,dir.y/dir.length*thickness/2);
		s.graphics.beginFill(color,1);
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
		
		var tf:TextField = null;
		if (s.numChildren>0 && s.getChildAt(0) is TextField) 
		{
			tf = (TextField)(s.removeChildAt(0));
		}
		else
		{
			tf = new TextField();
			var tff:TextFormat = tf.defaultTextFormat;
			tff.color = 0x999999;
			tf.defaultTextFormat = tff;
			tf.autoSize = "left";
			tf.wordWrap = false;
			tf.selectable = false;
		}
		var bnds:Rectangle = s.getBounds(s);
		tf.text = int(calculateArea(poly)/100)/100+"m sq.";
		tf.x = bnds.left+(bnds.width-tf.width)/2;
		tf.y = bnds.top+(bnds.height-tf.height)/2;
		s.addChild(tf);
		return s;
	}//endfunction
	
	//=============================================================================================
	// find cyclics, i.e. room floor areas
	//=============================================================================================
	public var debugStr:String = "";
	public function findIsolatedAreas():Vector.<Vector.<Point>>
	{
		var R:Vector.<Vector.<Point>> = new Vector.<Vector.<Point>>();	// results
		
		if (Joints.length==0)	return R;
		
		var timr:uint = getTimer();
		
		//-------------------------------------------------------------------------------
		function polyIsIn(poly:Vector.<Point>,bigPoly:Vector.<Point>):Boolean
		{
			for (var i:int=poly.length-1; i>-1; i--)
				if (bigPoly.indexOf(poly[i])==-1 && !pointInPoly(poly[i],bigPoly))
					return false;
			return true;
		}//endfunction
		
		//-------------------------------------------------------------------------------
		function seek(curJoint:Point,path:Vector.<Point>) : void
		{
			var i:int=0;
			if (path.indexOf(curJoint)!=-1)
			{
				var lop:Vector.<Point> = path.slice(path.indexOf(curJoint));
				if (lop.length>2)
				{	
					
					for (i=R.length-1; i>-1; i--)
					{
						if (polyIsIn(R[i],lop))		// contains another smaller loop
							return;
						else if (polyIsIn(lop,R[i]))	// is being contained
							R.splice(i,1);			// remove bigger loop that contains it
					}
					
					// binary insert longest loop at n shortest at 0
					var p:int = 0;
					var q:int = R.length-1;
					while (p<=q)
					{
						var m:int = (p+q)/2;
						if (R[m].length<lop.length)
							p=m+1;
						else
							q=m-1;
					}
					R.splice(p,0,lop);	// insert at posn
				}
			}
			else
			{
				// walk all edges
				var edges:Vector.<Wall> = connectedToJoint(curJoint);
				path = path.slice();	// duplicate
				path.push(curJoint);
				
				for (i=R.length-1; i>-1; i--)
					if (polyIsIn(R[i],path))	// contains another existing smaller loop
						return;					// prune off
				
				for (i=edges.length-1; i>-1; i--)
				{
					if (edges[i].joint1==curJoint)	
						seek(edges[i].joint2,path);
					else
						seek(edges[i].joint1,path);
				}
			}
		}//endfunction
		
		seek(Joints[0],new Vector.<Point>());
		
		debugStr= "seek t="+(getTimer()-timr)+" R.length="+R.length;
		
		return R;
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
			var limit:int = P.length;
			do {
				P.push(P.shift());
				limit--;
			} while (!edgeInPoly(P[0].x,P[0].y,P[2].x,P[2].y,P) && limit>0);	// chk cut line is actually in poly
			if (limit<=0) 
				return new Vector.<Point>();		// error occurred
			R.push(P[0],P[1],P[2]);	// push triangle in result
			P.splice(1,1);			// remove P[1]
		}
		if (P.length==3)
		R.push(P[0],P[1],P[2]);
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
	//
	//=======================================================================================
	public function addDoor(door:Door):void
	{
		Doors.push(door);
		addChild(door.icon);
	}//endfunction
	
	//=======================================================================================
	//
	//=======================================================================================
	public function removeDoor(door:Door):void
	{
		if (Doors.indexOf(door)!=-1)
		{
			Doors.splice(Doors.indexOf(door),1);
			if (door.icon.parent==this) removeChild(door.icon);
		}
	}//endfunction
	
	//=======================================================================================
	//
	//=======================================================================================
	public function chkPlaceDoor(pt:Point, width:Number):Point
	{
		var wallV:Point = joint2.subtract(joint1);
		var wallL:Number = wallV.length;
		wallV.normalize(1);
		var proj:Number = (pt.x-joint1.x)*wallV.x + (pt.y-joint1.y)*wallV.y;	// ratio along wall where door is at
		var a:Number = proj/wallL-0.5*width/wallL;	// door span along wallL
		var b:Number = proj/wallL+0.5*width/wallL;
		if (a<0 || b>1)	return null;	//exceed wall limit
		
		for (var i:int=Doors.length-1; i>-1; i--)		// check if overlap other doors
		{
			var c:Number = Doors[i].pivot;
			var d:Number = Doors[i].dir+c;
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
	public var icon:Sprite=null;
	
	public function Door(piv:Number,wid:Number,ico:Sprite):void
	{
		pivot = piv;
		dir = wid;
		icon = ico;
	}//endfunction
}//endclass