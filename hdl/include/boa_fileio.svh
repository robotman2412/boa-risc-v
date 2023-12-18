
// Copyright © 2023, Julian Scheffers, see LICENSE for more information



// Get the path of the parent directory without trailing /.
function automatic string boa_parentdir(string path);
    begin
        integer i, found;
        found = -1;
        for (i = 0; i < path.len(); i = i + 1) begin
            if (path.getc(i) == "/" || path.getc(i) == "\\") begin
                found = i;
            end
        end
        if (found == -1) begin
            return ".";
        end else begin
            return path.substr(0, found);
        end
    end
endfunction

// Load the entire contents of a file.
function automatic string boa_load_file(string path);
    begin
        integer fd;
        string data, tmp;
        data = "";
        fd = $fopen(path, "r");
        if (!fd) begin
            $display("Error opening %s", path);
            return "";
        end
        while (1) begin
            data = {data, tmp};
            tmp  = "";
            $fgets(tmp, fd);
            if (tmp.len() == 0) begin
                $fclose(fd);
                return data;
            end
        end
    end
endfunction
