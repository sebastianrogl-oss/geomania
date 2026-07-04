Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public static class BgRemover {
    public static void RemoveWhite(string path, int threshold = 35) {
        Bitmap src = new Bitmap(path);
        int w = src.Width, h = src.Height;
        Bitmap out2 = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(out2))
            g.DrawImage(src, 0, 0);
        src.Dispose();

        int lo = 255 - threshold;
        bool[,] visited = new bool[h, w];
        Queue<int[]> q = new Queue<int[]>();

        Action<int,int> seed = (x, y) => {
            if (visited[y,x]) return;
            Color px = out2.GetPixel(x, y);
            if (px.R > lo && px.G > lo && px.B > lo) {
                visited[y,x] = true;
                q.Enqueue(new int[]{y, x});
            }
        };

        for (int y = 0; y < h; y++) { seed(0, y); seed(w-1, y); }
        for (int x = 0; x < w; x++) { seed(x, 0); seed(x, h-1); }

        int[][] dirs = { new[]{-1,0}, new[]{1,0}, new[]{0,-1}, new[]{0,1} };
        while (q.Count > 0) {
            int[] cell = q.Dequeue();
            int cy = cell[0], cx = cell[1];
            out2.SetPixel(cx, cy, Color.Transparent);
            foreach (int[] d in dirs) {
                int ny = cy + d[0], nx = cx + d[1];
                if (ny >= 0 && ny < h && nx >= 0 && nx < w && !visited[ny,nx]) {
                    Color px = out2.GetPixel(nx, ny);
                    if (px.R > lo && px.G > lo && px.B > lo) {
                        visited[ny,nx] = true;
                        q.Enqueue(new int[]{ny, nx});
                    }
                }
            }
        }

        out2.Save(path, ImageFormat.Png);
        out2.Dispose();
        Console.WriteLine("Done: " + System.IO.Path.GetFileName(path));
    }
}
"@ -ReferencedAssemblies System.Drawing

$base = "C:\Users\sebas\geomania\assets\icons"
foreach ($name in @("challenge_preis.png","challenge_higher_lower.png","challenge_ranking.png","challenge_portfolio.png")) {
    [BgRemover]::RemoveWhite("$base\$name", 35)
}
Write-Host "Fertig."
