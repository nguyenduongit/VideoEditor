import Foundation
import Domain

public enum MCPToolSchemas {
    public static let toolList: [MCPToolDescriptor] = [
        MCPToolDescriptor(
            name: "timeline_get_state",
            description: "Retrieves the current state of the timeline, including all tracks, clips, properties (textConfig, adjustmentConfig), and time ranges.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "includeDetails": { "type": "boolean", "description": "Set true to include full project JSON" }
              }
            }
            """
        ),
        MCPToolDescriptor(
            name: "library_get_catalog",
            description: "Lists all imported media assets (video/audio/image files in Media Library), available Text Templates (19 presets), Adjustment Color Templates (16 presets), and available Vietnamese & System Fonts.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "filter": { "type": "string", "description": "Optional filter: 'all', 'media', 'text', 'adjustment', or 'fonts'" }
              }
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_add_media_asset",
            description: "Adds an imported media asset from the Media Library onto the timeline by assetId or fileName.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "assetId": { "type": "string", "description": "UUID of the media asset (optional if fileName is provided)" },
                "fileName": { "type": "string", "description": "Name or partial name of the media file (e.g. IMG_5671.MOV or .mp3)" },
                "startTimeSeconds": { "type": "number", "description": "Start time in seconds on the timeline (default 0)" }
              }
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_sync_audio",
            description: "Automatically adds Video and Audio from Media Library if not yet on timeline, aligns/synchronizes their audio waveforms, mutes original video audio track when requested, and trims excess video and audio at both ends.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "muteVideo": { "type": "boolean", "description": "Mute the original video audio track after syncing external music (default true)" },
                "trimExcessTail": { "type": "boolean", "description": "Automatically trim excess video and audio at both ends (default true)" }
              }
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_apply_template",
            description: "Applies or updates a Text Template or Adjustment Color Grading Template on the timeline with optional custom styling, colors, stroke, glow, background, fonts, animations, or grading parameters.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "kind": { "type": "string", "description": "'text' or 'adjustment'" },
                "templateId": { "type": "string", "description": "Template ID (e.g. 'cinematic', 'vivid', 'korean_glow', 'kodak_2383_film', 'cyberpunk', 'neon_cyber_pulse', '3d_pop_headline', 'cinematic_gold_title')" },
                "updateExisting": { "type": "boolean", "description": "If true, updates the existing text or adjustment clip on the timeline instead of adding a new one" },
                "customText": { "type": "string", "description": "Text content to display when kind is 'text'" },
                "fontName": { "type": "string", "description": "Artistic font name from the 200+ UVN font library or system (e.g. 'UVN Bay Buom', 'UVN Da Lat', 'UVN Ke Chuyen', 'UVN Bach Dang', 'UVN Thoi Nay', 'UVN Van', 'UVN Sai Gon', 'Impact', 'Helvetica')" },
                "fontSize": { "type": "number", "description": "Font size (e.g. 40 to 120) when kind is 'text'" },
                "textColorHex": { "type": "string", "description": "Hex color for text fill (e.g. '#FFFFFF', '#FFE66D', '#00F5D4')" },
                "strokeColorHex": { "type": "string", "description": "Hex color for text outline/border (e.g. '#000000', '#023047')" },
                "strokeWidth": { "type": "number", "description": "Outline stroke width (0 to 20)" },
                "glowColorHex": { "type": "string", "description": "Hex color for neon glow effect (e.g. '#00BBF9', '#FF007F', '#FFD166')" },
                "glowRadius": { "type": "number", "description": "Glow blur radius (0 to 40, >0 enables glow)" },
                "hasBackground": { "type": "boolean", "description": "Set true to display background banner box for subtitle or headline" },
                "backgroundColorHex": { "type": "string", "description": "Background hex color (e.g. '#000000', '#0F172A', '#FFE66D')" },
                "backgroundOpacity": { "type": "number", "description": "Background opacity from 0.0 to 1.0 (default 0.7)" },
                "backgroundPadding": { "type": "number", "description": "Background padding in pixels (e.g. 12)" },
                "backgroundCornerRadius": { "type": "number", "description": "Background corner radius in pixels (e.g. 8)" },
                "inAnimation": { "type": "string", "description": "Entrance animation: 'flyInTop', 'flyInBottom', 'flyInLeft', 'flyInRight', 'vortexSpin', 'shockwaveBlast', 'crashBounce', 'neonFlicker', 'flip3D', 'fadeIn', 'zoomIn', 'popBounce', 'blurIn', 'slideUp', 'typewriter'" },
                "outAnimation": { "type": "string", "description": "Exit animation: 'flyOutBottom', 'flyOutTop', 'flyOutLeft', 'flyOutRight', 'spiralFlyAway', 'shockwaveBlast', 'pixelateDissolve', 'fadeOut', 'zoomOut', 'blurOut', 'fallDown', 'slideDown'" },
                "loopAnimation": { "type": "string", "description": "Loop animation: 'none', 'heartbeat', 'neonPulse', 'earthquake', 'pulse', 'floating', 'wiggle', 'rainbow', 'glitch'" },
                "motionEasing": { "type": "string", "description": "Motion easing curve: 'Smooth', 'Bounce', 'Elastic'" },
                "position": { "type": "string", "description": "Safe visual placement preset: 'top' (safe header above subject's head in open sky/headroom, avoids covering faces), 'bottom' (safe subtitle below feet), or 'center' (screen center)" },
                "positionX": { "type": "number", "description": "Horizontal offset in pixels (-400 to 400, 0 is center)" },
                "positionY": { "type": "number", "description": "Vertical offset in pixels (-400 to 400, negative is higher up/towards top)" },
                "exposure": { "type": "number", "description": "Adjustment exposure (-100 to 100)" },
                "contrast": { "type": "number", "description": "Adjustment contrast (-100 to 100)" },
                "highlight": { "type": "number", "description": "Adjustment highlights (-100 to 100)" },
                "shadow": { "type": "number", "description": "Adjustment shadows (-100 to 100, positive brightens dark areas)" },
                "saturation": { "type": "number", "description": "Adjustment saturation (-100 to 100)" },
                "brilliance": { "type": "number", "description": "Adjustment vibrance/brilliance (-100 to 100, positive makes colors fresh and bright)" },
                "temp": { "type": "number", "description": "Adjustment color temperature (-100 cool to 100 warm)" },
                "vignetteAmount": { "type": "number", "description": "Adjustment vignette (-100 to 100)" },
                "startTimeSeconds": { "type": "number", "description": "Start time in seconds on timeline (defaults to 0.0 / start of video clips, avoiding placing at random playhead position)" },
                "durationSeconds": { "type": "number", "description": "Duration in seconds (defaults to full video length for adjustment clips, or 5.0s for text)" }
              },
              "required": ["kind"]
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_edit_clip",
            description: "Performs direct editing operations on timeline clips or project: split clip, trim clip duration, move clip, remove clip, change canvas aspect ratio, or seek playhead.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "operation": { "type": "string", "description": "'split', 'trim', 'move', 'remove', 'setAspectRatio', or 'seek'" },
                "clipId": { "type": "string", "description": "UUID or name of the target clip (or 'video', 'audio', 'text', 'adjustment' to target first clip of that kind)" },
                "atTimeSeconds": { "type": "number", "description": "Time in seconds (for 'split', start time for 'move'/'trim', or target playhead time for 'seek')" },
                "newDurationSeconds": { "type": "number", "description": "New duration in seconds (for 'trim')" },
                "aspectRatio": { "type": "string", "description": "Target aspect ratio for 'setAspectRatio': '16:9', '9:16', '1:1', '4:3', '21:9'" }
              },
              "required": ["operation"]
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_execute_commands",
            description: "Executes a batch of declarative TimelineCommand objects.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "commands": {
                  "type": "array",
                  "description": "Array of TimelineCommand objects",
                  "items": {
                    "type": "object",
                    "properties": {
                      "action": { "type": "string", "description": "Command action name" }
                    }
                  }
                }
              },
              "required": ["commands"]
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_export_project_script",
            description: "Exports the entire editing project into a portable JSON script.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "title": { "type": "string", "description": "Project title" }
              }
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_load_project_script",
            description: "Loads and replaces the timeline with a given ProjectScript JSON string.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "projectJSON": { "type": "string", "description": "Serialized ProjectScript JSON string" }
              },
              "required": ["projectJSON"]
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_get_clip_color_telemetry",
            description: "Extracts headless color telemetry and histogram analysis (exposure, white balance cast, clipping) from a clip on the timeline for AI color grading.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "clipId": { "type": "string", "description": "ID or name of the clip to analyze" }
              },
              "required": ["clipId"]
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_ai_vision_framing",
            description: "Runs Apple Vision human body pose detection on the video clip to automatically center the character (Auto Pan), adjust video scale so the character fits a target height ratio (e.g. 0.33 for 1/3 frame height), and balance/stretch character height & leg proportions (3-zone leg stretch 0.90 to 1.30 with dynamic waist & ankle lines).",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "enableAutoPan": { "type": "boolean", "description": "Enable Auto Pan to keep character centered horizontally in frame (default true)" },
                "autoPanSmoothness": { "type": "number", "description": "Camera tracking smoothness from 0.0 to 1.0 (default 0.6)" },
                "enableLegStretch": { "type": "boolean", "description": "Enable 3-zone body/leg height proportion adjustment using Vision waist & ankle lines (default true)" },
                "legStretchRatio": { "type": "number", "description": "Constant leg/height stretch ratio from 0.90 to 1.30 (1.0 is original, 1.12 to 1.18 makes legs longer and body taller/balanced)" },
                "targetSubjectHeightRatio": { "type": "number", "description": "Desired character height relative to frame height (e.g. 0.33 for 1/3 frame height, 0.5 for half frame height)" },
                "scale": { "type": "number", "description": "Optional explicit video scale multiplier (1.0 to 2.5)" },
                "centerSubject": { "type": "boolean", "description": "Center the character in the frame horizontally and vertically without black borders (default true)" }
              }
            }
            """
        )
    ]
}
