import Foundation
import Domain

public enum MCPToolSchemas {
    public static let toolList: [MCPToolDescriptor] = [
        MCPToolDescriptor(
            name: "timeline_get_state",
            description: "Retrieves the current state of the timeline, including all tracks, clips, and time ranges.",
            inputSchema: """
            {
              "type": "object",
              "properties": {}
            }
            """
        ),
        MCPToolDescriptor(
            name: "timeline_execute_commands",
            description: "Executes a batch of declarative editing commands (addClip, moveClip, trimClip, removeClip, setLayerStatus, splitClip).",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "commands": {
                  "type": "array",
                  "description": "Array of TimelineCommand objects"
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
            description: "Loads and replaces the timeline with a given ProjectScript JSON.",
            inputSchema: """
            {
              "type": "object",
              "properties": {
                "project": { "type": "object", "description": "ProjectScript JSON object" }
              },
              "required": ["project"]
            }
            """
        )
    ]
}
