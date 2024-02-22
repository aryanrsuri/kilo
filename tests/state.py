import numpy as np
import chess


class State(object):
    def __init__(self, board=None):
        if board is None:
            self.board = chess.Board()
        else:
            self.board = board

    def serialise(self):
        # 64x5
        assert (self.board.is_valid())
        bstate = np.zeros(64, np.uint8)
        for i in range(64):
            pos = self.board.piece_at(i)
            if pos is not None:
                bstate[i] = {"P": 1, "N": 2, "B": 3, "R": 4,
                             "Q": 5, "K": 6, "p": 7, "n": 8, "b": 9, "r": 10, "q": 11, "k": 12}[pos.symbol()]
                # print(bstate[i])
                pass
        # bstate =
        bstate = bstate.reshape(8, 8)
        # exit(0)
        state = np.zeros((8, 8, 5), np.uint8)
        state[:, :, 0] = (bstate >> 3) & 1
        state[:, :, 1] = (bstate >> 2) & 1
        state[:, :, 2] = (bstate >> 1) & 1
        state[:, :, 3] = (bstate >> 0) & 1
        state[:, :, 4] = (self.board.turn*1.0)
        fen = self.board.shredder_fen()
        return state

    def value(self):
        return 1

    def edges(self):
        return list(self.board.generate_legal_moves())


if __name__ == "__main__":
    s = State()
    print(s.edges())
