
import java.io.*;
import java.nio.ByteBuffer;
import java.util.HashMap;

public class NoteConverter {
    private static final HashMap<String, Integer> map = new HashMap<>();

    static {
        map.put("C", 262);
        map.put("C#", 277);
        map.put("D", 294);
        map.put("D#", 311);
        map.put("E", 329);
        map.put("F", 349);
        map.put("F#", 370);
        map.put("G", 392);
        map.put("G#", 415);
        map.put("A", 440);
        map.put("A#", 466);
        map.put("B", 493);
        map.put("^C", 523);
        map.put("^C#", 554);
        map.put("^D", 572);
        map.put("^D#", 622);
        map.put("^E", 659);
        map.put("^F", 698);
        map.put("^F#", 740);
        map.put("^G", 784);
        map.put("^G#", 830);
        map.put("^A", 880);
        map.put("^A#", 932);
        map.put("^B", 987);
    }

    public static void main(String[] args) throws IOException {
        if (args.length != 3){
            System.err.println("Usage:" +
                    "converter notes.dat notes.bin times.bin");
            System.exit(-1);
        }
        BufferedReader br = new BufferedReader(new FileReader(new File(args[0])));
        FileOutputStream nos = new FileOutputStream(new File(args[1]));
        FileOutputStream tos = new FileOutputStream(new File(args[2]));

        int i = 0;
        while (br.ready()) {
            String token = nextToken(br);
            System.out.print(token);
            Integer freq = map.get(token.replace(".", ""));
            System.out.print(" : ");
            System.out.println(freq);
            if (freq != null) {
                i+=2;
                writeShort(nos, freq.shortValue());
                writeLength(tos, Length.NORMAL);
                writePause(nos);
                writeLength(tos, Length.SHORT);
            }
            if (token.endsWith(".")) {
                System.out.println("Pause");
                i++;
                writePause(nos);
                writeLength(tos, Length.LONG);
            }
        }
        nos.flush();
        nos.close();
        tos.flush();
        tos.close();
        System.out.println("Words written: " + i);
    }

    private static void writeLength(FileOutputStream fos, Length length) throws IOException {
        writeShort(fos, (short) length.getLength());
    }

    private static void writeShort(FileOutputStream fos, short data) throws IOException {
        ByteBuffer buf = ByteBuffer.allocate(2);
        buf.putShort(data);
        fos.write(buf.array(), 1, 1);
        fos.write(buf.array(), 0, 1);
    }

    private static void writePause(FileOutputStream fos) throws IOException {
        fos.write(new byte[]{0, 0});
    }

    private static String nextToken(BufferedReader br) throws IOException {
        StringBuilder sb = new StringBuilder();
        while (br.ready()) {
            int token = br.read();
            switch (token) {
                case '$':
                    br.readLine();
                    break;
                case ' ':
                case '\t':
                case '\n':
                    if (sb.length() > 0) {
                        return sb.toString();
                    }
                    break;
                default:
                    sb.append((char) token);
                    break;
            }
        }
        return "";
    }

    private enum Length {
        SHORT(45),
        NORMAL(90 * 3),
        LONG(90 * 4);

        private final int length;

        Length(int length) {
            this.length = length;
        }

        public int getLength() {
            return length;
        }
    }
}
