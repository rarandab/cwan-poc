# How to Create architecture.png

Since I cannot directly create PNG images, here are several options to create the `architecture.png` file:

## Option 1: Use Mermaid Live Editor (Recommended - Easiest)

1. Go to https://mermaid.live/
2. Open the file `architecture.md` in this repository
3. Copy the Mermaid diagram code (everything between the ```mermaid and ``` markers)
4. Paste it into the Mermaid Live Editor
5. The diagram will render automatically
6. Click the "Download PNG" button
7. Save the file as `architecture.png` in the project root

## Option 2: Use Mermaid CLI

If you have Node.js installed:

```bash
# Install Mermaid CLI
npm install -g @mermaid-js/mermaid-cli

# Convert the diagram to PNG
mmdc -i architecture.md -o architecture.png -b transparent
```

## Option 3: Use VS Code Extension

1. Install the "Markdown Preview Mermaid Support" extension in VS Code
2. Open `architecture.md`
3. Click the preview button (Ctrl+Shift+V or Cmd+Shift+V)
4. Right-click on the rendered diagram
5. Select "Copy Image" or "Save Image As"
6. Save as `architecture.png`

## Option 4: Use Draw.io (Most Customizable)

1. Open https://app.diagrams.net/ (Draw.io)
2. Follow the detailed instructions in `ARCHITECTURE-DRAWIO-GUIDE.md`
3. Create the diagram manually using the guide
4. Export as PNG:
   - File → Export as → PNG
   - Set resolution to 300 DPI
   - Enable "Transparent Background" if desired
   - Click "Export"
5. Save as `architecture.png`

## Option 5: Use AWS Architecture Icons (Most Professional)

1. Download AWS Architecture Icons from:
   https://aws.amazon.com/architecture/icons/
2. Use PowerPoint, Visio, or Draw.io
3. Follow the structure in `ARCHITECTURE-DRAWIO-GUIDE.md`
4. Use official AWS icons for each service
5. Export as high-resolution PNG

## Option 6: Use Python with Diagrams Library

If you have Python installed:

```bash
# Install diagrams library
pip install diagrams

# Create a Python script using the diagrams library
# (Would need to write custom Python code based on architecture)
```

## Recommended Approach

For the best results, I recommend:

1. **Quick Preview**: Use Mermaid Live Editor (Option 1) - Takes 2 minutes
2. **Professional Diagram**: Use Draw.io with AWS icons (Option 4 + 5) - Takes 30-60 minutes

## Image Specifications

When creating the PNG, use these settings:

- **Format**: PNG
- **Resolution**: 300 DPI minimum
- **Dimensions**: 1920x1080 or larger (landscape orientation)
- **Background**: White or transparent
- **File Size**: Aim for under 2MB for GitHub
- **Color Depth**: 24-bit color

## What to Include in the Diagram

Make sure your diagram shows:

1. ✓ On-Premises / SD-WAN section with BGP details
2. ✓ AWS Cloud WAN Core Network with segments
3. ✓ Network Function Group (NFG) for inspection
4. ✓ All 4 regions (eu-central-1, eu-south-2, eu-south-1, eu-west-1)
5. ✓ Inspection VPCs (NFG and NFW) in inspection-enabled regions
6. ✓ Shared Services VPCs in all regions
7. ✓ SD-WAN VPC in eu-central-1
8. ✓ Workload VPCs in all regions
9. ✓ Connection lines showing:
   - BGP peering (SD-WAN to Cloud WAN)
   - VPC attachments to segments
   - Inspection flow (send-via)
   - Segment sharing relationships
10. ✓ Legend explaining colors and connection types

## Verification

After creating the PNG, verify it includes:

- [ ] Clear labels for all components
- [ ] Readable text at normal zoom levels
- [ ] Proper color coding (see ARCHITECTURE-DRAWIO-GUIDE.md)
- [ ] All regions and VPCs
- [ ] Connection arrows with labels
- [ ] Legend
- [ ] Title: "AWS Cloud WAN PoC Architecture"

## Alternative: Use the Text Diagram

If you cannot create a PNG, the `architecture.txt` file provides a text-based ASCII diagram that can be viewed in any text editor or terminal.

## Need Help?

If you need assistance creating the diagram:

1. Use the Mermaid Live Editor - it's the fastest way
2. The Mermaid code in `architecture.md` is complete and ready to use
3. Just copy, paste, and download!
