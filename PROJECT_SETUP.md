# Land of the Kaijuz - Project Setup Guide

## Project Structure

Your Godot 4.4 project is now set up with a scalable structure for a farming/adventure game with 8-directional movement and A* pathfinding.

### Folder Structure
```
├── scenes/
│   ├── characters/player/     # Player character scenes
│   ├── characters/npcs/       # NPC scenes
│   ├── characters/enemies/    # Enemy character scenes
│   ├── levels/world/          # World/level scenes
│   ├── levels/interiors/      # Interior scenes
│   ├── levels/ui/             # UI scenes
│   ├── components/            # Reusable component scenes
│   └── autoloads/             # Autoload scenes
├── scripts/
│   ├── characters/            # Character scripts
│   ├── systems/               # Game system scripts
│   ├── managers/              # Manager scripts
│   ├── components/            # Component scripts
│   └── autoloads/             # Autoload scripts
├── prefabs/
│   ├── characters/            # Character prefabs
│   ├── environment/           # Environment prefabs
│   ├── ui/                    # UI prefabs
│   └── effects/               # Effect prefabs
└── assets/                    # Your existing asset folders
```

## Core Systems

### Autoloaded Managers
- **GameManager**: Scene management, save/load, game state
- **InputManager**: Centralized input handling (keyboard + touch)
- **NavigationManager**: A* pathfinding system
- **AudioManager**: Sound effects and music management
- **DebugManager**: Development debugging tools

### Player System
- **8-directional movement** with smooth animations
- **Tap-to-move functionality** with A* pathfinding
- **Keyboard controls** (WASD) for direct movement
- **Camera system** with smooth following

## Setting Up Player Animations

1. **Install AnimSheet Plugin** (if not already installed):
   - Go to AssetLib in Godot
   - Search for "AnimSheet" 
   - Install and enable the plugin

2. **Set up Player Animations**:
   - Open `scenes/characters/player/Player.tscn`
   - Select the `AnimatedSprite2D` node
   - In the inspector, create a new `SpriteFrames` resource
   - Set the texture to `assets/Player/Player_Base/Player_Base_animations.png`
   - Use AnimSheet to automatically slice animations:

**Expected Animation Names** (the code expects these):
- `idle_down`, `idle_up`, `idle_left`, `idle_right`
- `idle_down_left`, `idle_down_right`, `idle_up_left`, `idle_up_right`
- `walk_down`, `walk_up`, `walk_left`, `walk_right`
- `walk_down_left`, `walk_down_right`, `walk_up_left`, `walk_up_right`

## Tile Setup with TileMapLayer (Godot 4.4)

The project uses the new TileMapLayer system:
- **GroundLayer**: Base terrain tiles
- **ObstacleLayer**: Obstacles and collision objects (y_sort enabled)
- **DecorationLayer**: Decorative elements (y_sort enabled)

To add tiles:
1. Open `scenes/levels/world/MainWorld.tscn`
2. Select the TileMap node
3. Paint tiles on the appropriate layers
4. Update the NavigationRegion2D if needed for pathfinding

## Controls

### Keyboard:
- **WASD**: Direct character movement
- **E**: Interact (if implemented)
- **I**: Inventory (if implemented)
- **Escape**: Pause (if implemented)
- **Enter**: Toggle navigation debug visualization

### Touch/Mouse:
- **Tap/Click**: Move to position using pathfinding

## Navigation System

The A* pathfinding system is set up with:
- **NavigationRegion2D** with a basic navigation polygon
- **Automatic pathfinding** for tap-to-move
- **Obstacle avoidance** (update NavigationPolygon as needed)

To add obstacles:
1. Edit the NavigationPolygon resource
2. Create holes in the navigation mesh for obstacles
3. The system will automatically path around them

## Debug Features

Press **Enter** during gameplay to see:
- FPS counter
- Autoload system status
- Player information (position, velocity, direction)
- Navigation system status
- Control instructions

## Next Steps

1. **Set up animations** using AnimSheet plugin
2. **Paint world tiles** in the TileMap layers
3. **Add obstacles** by updating the NavigationPolygon
4. **Test movement** with both keyboard and mouse/touch
5. **Add your game-specific features** (farming, NPCs, etc.)

## Mobile Optimization

The project is configured for mobile:
- Touch input handling
- Appropriate window size (1080x1920)
- Mobile renderer
- Battery-efficient updates

## File Locations

- **Main scene**: `scenes/levels/world/MainWorld.tscn`
- **Player scene**: `scenes/characters/player/Player.tscn`
- **Core systems**: `scripts/autoloads/`
- **Navigation**: `scenes/levels/world/NavigationPolygon.tres`

The system is designed to be modular and scalable. Each component can be extended or modified independently as your game grows in complexity.
